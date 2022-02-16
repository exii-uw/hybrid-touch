
/**
 * The touch data that's reported by the powerwall is very noisy. There are
 * frequent phantom touches (and touch-ups), and the input is noisy. We take
 * in that information and apply a few transformations to it.
 *
 * TOUCH_DOWN_TIME_THRESHOLD is how long in milliseconds a touch needs to be detected
 * before it's considered to be a real touch. TOUCH_UP_TIME_THRESHOLD is how long
 * a touch can be missing before it's considered to be a real touch-up.
 * TOUCH_UP_DISTANCE_THRESHOLD is how far away a touch can be before it's considered
 * part of the "same" touch -- if we detect two touches within
 * TOUCH_UP_DISTANCE_THRESHOLD of each other, the second is discarded. In addition,
 * if we see a touch-up event and a touch-down event within
 * TOUCH_UP_TIME_THRESHOLD and TOUCH_UP_DISTANCE_THRESHOLD of the touch-up, then those
 * touch-up and touch-down events are considered not to have happened, and
 * instead there was a touch-move from the former to the latter.
 *
 * We also apply the one-euro filter to all touch inputs. Touch inputs on non-
 * noisy machines (such as my laptop) have random noise automatically added and
 * are then quantized to help simulate the conditions on the powerwall.
 *
 * NOTE: to use this module, an external module must define the
 * filteredTouchDown, filteredTouchMove, filteredToucUp, filteredTouchTap, and
 * filteredTouchSignificantMove functions.
 */


// Flowchart:
//
//                 [A]
//                  |
// touchDown: touch is added to currentTouches
//                  |
//     .------------'-----------.-------------------.
//     |                        |                   |
// touchUp: touch is removed    |   TOUCH_DOWN_TIME_THRESHOLD exceeded and
// from currentTouches          |   touch is consumed by C: touch is
//                              |   removed from currentTouches
//                              |
//                              |
//          TOUCH_DOWN_TIME_THRESHOLD exceeded and touch is not consumed by C:
//          hybridTouchDown triggers
//                              |
//                             [B]
//            .-----------------^-------------------.
//            |                                     |
// touchMove: hybridTouchMove       touchUp: touch is removed from
// triggers                         currentTouches and added to
//                                  recentlyLiftedTouches
//                                                  |
//            .-------------------------------------'-------.
//            |                                             |
// touchDown within TOUCH_UP_DISTANCE_THRESHOLD:     TOUCH_UP_TIME_THRESHOLD exceeded:
// [C] touch is removed from                    hybridTouchUp triggers. touch
// recentlyLiftedTouches and inserted back      is removed from
// into currentTouches with the new ID. Go      recentlyLiftedTouches.
// to B.                                        If the length of the touch was
//                                              less than
//                                              TOUCH_TAP_TIME_THRESHOLD,
//                                              trigger hybridTouchTap.


// Note that TOUCH_UP_TIME_THRESHOLD has to be longer than TOUCH_DOWN_TIME_THRESHOLD,
// otherwise recently lifted touches will be discarded before new touches can
// be considered non-spurious and continue them.
// Times are all measured in *milliseconds*, not *frames*.
private final int TOUCH_DOWN_TIME_THRESHOLD = 20;
private final float TOUCH_DOWN_DISTANCE_THRESHOLD = 64.0;
private final int TOUCH_UP_TIME_THRESHOLD = 40;
private final float TOUCH_UP_DISTANCE_THRESHOLD = 64.0;
private final int TOUCH_TAP_TIME_THRESHOLD = 400;
private final float TOUCH_TAP_DISTANCE_THRESHOLD = 64.0;

// Multiplied with the velocity of a lifted touch every frame.
private final float TOUCH_LIFTED_PROJECTION_FRICTION = 0.9;

// Sometimes the stupid stupid stupid powerwall gets stuck touches on it. Some
// of them one can avoid by pulling the touch border out from the screens. But
// the top border is a real pain in the tush. So you know what? We're just
// going to totally ignore any touches coming from right next to the touch
// frame, i.e. the edge of the screen. Fuck you, powerwall.
// January 2015: This is actually not such a big issue anymore, since we've
// adjusted how far out the touch frame is from the screens. Value changed from
// 64 to 4.
private final int IGNORE_BORDER = 64;

// To make things easier, we generate our own touch IDs for fingers instead of
// using the values provided by the driver. This counter contains the next
// valid finger touch. In theory, you could end up with a conflict here if you
// managed to hold a touch down and then made 2^32 other touches. Hopefully,
// that will not happen. There should probably be a mutex on this if you're
// going to do weird multithreading things.
private int CURRENT_TOUCH_ID = 0;


/**
 * Return all active touches, as decided by the filter. Don't modify the return
 * value!
 * @return a list of active touches
 */
List<FilteredTouch> getFilteredTouches() {
    return publicTouches;
}


/**
 * Draw the current raw touch input in red, and the current filtered touch
 * input in green, and the current filtered lifted touches in blue.
 */
void displayDebugTouchInput() {
    displayDebugIgnoreBorder(IGNORE_BORDER);
    for (Touch touch: SMT.getTouches()) {
        PVector touchPosition = inputSpaceToMachineSpace(new PVector(touch.x, touch.y));
        displayDebugRawTouch(touchPosition.x, touchPosition.y);
    }
    for (FilteredTouch touch: currentTouches) {
        if (touch.hasTriggeredTouchDownEvent) {
            displayDebugFilteredTouch(touch.x, touch.y, touch.canTriggerTouchTap());
        }
    }
    for (FilteredTouch touch: recentlyLiftedTouches) {
        displayDebugLiftedTouch(touch.x, touch.y);
    }
}


/**
 * Draw the current filtered touch input in green.
 */
void displayUserTouchInput() {
    for (FilteredTouch touch: currentTouches) {
        if (touch.hasTriggeredTouchDownEvent) {
            displayDebugFilteredTouch(touch.x, touch.y, touch.canTriggerTouchTap());
        }
    }
}


/**
 * Update the touch input by one frame.
 */
void updateTouchInputFilter() {
    long time = System.currentTimeMillis();
    // Project recently lifted touches.
    for (FilteredTouch recentlyLiftedTouch: recentlyLiftedTouches) {
        recentlyLiftedTouch.x += recentlyLiftedTouch.xVelocity;
        recentlyLiftedTouch.y += recentlyLiftedTouch.yVelocity;
        recentlyLiftedTouch.xVelocity *= TOUCH_LIFTED_PROJECTION_FRICTION;
        recentlyLiftedTouch.yVelocity *= TOUCH_LIFTED_PROJECTION_FRICTION;
    }
    // Check for touchDown events.
    for (FilteredTouch touch: currentTouches) {
        if (!touch.hasTriggeredTouchDownEvent && time - touch.touchDownTime > TOUCH_DOWN_TIME_THRESHOLD) {
            // This touch has existed long enough for us to consider it real
            // and not spurious. Check to make sure it isn't a spurious
            // lifting; if it is, then we revive the recently lifted touch
            // without triggering a hybridTouchDown or a hybridTouchUp, and
            // instead just trigger a hybridTouchMove. Otherwise, it's its
            // own unique touch, and so should trigger a hybridTouchDown.
            FilteredTouch touchContinuation = null;
            for (FilteredTouch recentlyLiftedTouch: recentlyLiftedTouches) {
                // Note that we don't need to check the touch time for the
                // recently lifted touch: it will have already been removed
                // from recentlyLiftedTouches if it's expired.
                PVector touchDistance = new PVector(touch.x - recentlyLiftedTouch.x,
                                                    touch.y - recentlyLiftedTouch.y);
                if (touchDistance.mag() <= TOUCH_UP_DISTANCE_THRESHOLD) {
                    // This touch was close enough to a recently lifted
                    // touch that we'll consider it a continuation.
                    touchContinuation = recentlyLiftedTouch;
                }
            }
            if (touchContinuation != null) {
                // Steal the new touch's contained TUIO fingers.
                touchContinuation.absorbed = touch.absorbed;
                touchContinuation.touchUpTime = 0;
                touchContinuation.updatePosition(touch.x, touch.y);
                recentlyLiftedTouches.remove(touchContinuation);
                touchesToAddToCurrentTouches.add(touchContinuation);
                touchesToRemoveFromCurrentTouches.add(touch);
            } else {
                // This is a new touch all of its own.
                publicTouches.add(touch);
                touch.triggerTouchDown();
            }
        }
    }
    for (FilteredTouch touch: touchesToAddToCurrentTouches) {
        currentTouches.add(touch);
    }
    touchesToAddToCurrentTouches.clear();
    for (FilteredTouch touch: touchesToRemoveFromCurrentTouches) {
        currentTouches.remove(touch);
    }
    touchesToRemoveFromCurrentTouches.clear();
    // Check for touchMove events.
    for (FilteredTouch touch: currentTouches) {
        if (!touch.hasTriggeredTouchMoveEvent && touch.hasTriggeredTouchDownEvent) {
            touch.triggerTouchMove();
        }
    }
    // Check for touchUp events.
    for (FilteredTouch touch: recentlyLiftedTouches) {
        if (time - touch.touchUpTime > TOUCH_UP_TIME_THRESHOLD) {
            publicTouches.remove(touch);
            touch.triggerTouchUp();
            touchesToRemoveFromRecentlyLiftedTouches.add(touch);
        }
    }
    for (FilteredTouch touch: touchesToRemoveFromRecentlyLiftedTouches) {
        recentlyLiftedTouches.remove(touch);
    }
}


private float beNoisy(float input) {
    return random(-1.0, 1.0) * machineNoise + input - (input % 2.0);
}


class FilteredTouch {
    int id;
    long touchDownTime;
    long touchUpTime;
    float x;
    float y;
    OneEuro xFilter;
    OneEuro yFilter;
    float xVelocity;
    float yVelocity;
    float rawX;
    float rawY;
    float originX;
    float originY;
    float distanceMoved;
    /**
     * all the touches that were close enough to this touch that they were
     * fully ignored.
     */
    ArrayList absorbed;
    /**
     * false until this touch triggers a hybridTouchDown event, then true from
     * then on.
     */
    boolean hasTriggeredTouchDownEvent;
    /**
     * true until this touch is moved; then false until the hybridTouchMove
     * event is triggered, then set back to true.
     */
    boolean hasTriggeredTouchMoveEvent;
    /**
     * The radius within which new touches will be absorbed into this touch.
     */
    float touchDownDistanceThreshold;
    FilteredTouch(int id, long touchDownTime, long touchUpTime, float x, float y) {
        this.id = CURRENT_TOUCH_ID++;
        this.touchDownTime = touchDownTime;
        this.touchUpTime = touchUpTime;
        this.xFilter = new OneEuro(30.0, 1.0, 0.007, 1);
        this.yFilter = new OneEuro(30.0, 1.0, 0.007, 1);
        this.x = this.originX = this.xFilter.filter(this.rawX = beNoisy(x));
        this.y = this.originY = this.yFilter.filter(this.rawY = beNoisy(y));
        this.xVelocity = 0.0;
        this.yVelocity = 0.0;
        this.absorbed = new ArrayList();
        this.absorbed.add(id);
        this.hasTriggeredTouchDownEvent = false;
        this.hasTriggeredTouchMoveEvent = true;
        this.touchDownDistanceThreshold = TOUCH_DOWN_DISTANCE_THRESHOLD;
    }
    void updatePosition(float x, float y) {
        x = beNoisy(x);
        y = beNoisy(y);
        this.rawX = x;
        this.rawY = y;
        this.xVelocity = x - this.x;
        this.yVelocity = y - this.y;
        this.hasTriggeredTouchMoveEvent = false;
    }
    void triggerTouchDown() {
        this.hasTriggeredTouchDownEvent = true;
        filteredTouchDown(this);
    }
    void triggerTouchMove() {
        float newX = this.xFilter.filter(this.x + this.xVelocity);
        float newY = this.yFilter.filter(this.y + this.yVelocity);
        this.xVelocity = newX - this.x;
        this.yVelocity = newY - this.y;
        this.x = newX;
        this.y = newY;
        PVector velocity = new PVector(this.xVelocity, this.yVelocity);
        this.distanceMoved += velocity.mag();
        this.hasTriggeredTouchMoveEvent = true;
        filteredTouchMove(this);
        if (!this.canTriggerTouchTap()) {
            filteredTouchSignificantMove(this);
        }
        this.xVelocity = 0.0;
        this.yVelocity = 0.0;
    }
    void triggerTouchUp() {
        filteredTouchUp(this);
        if (this.canTriggerTouchTap()) {
            filteredTouchTap(this);
        }
    }
    boolean canTriggerTouchTap() {
        return (this.touchUpTime == 0 ? System.currentTimeMillis() : this.touchUpTime) - this.touchDownTime < TOUCH_TAP_TIME_THRESHOLD
            && this.distanceMoved < TOUCH_TAP_DISTANCE_THRESHOLD;
    }
}


private List<FilteredTouch> publicTouches = new ArrayList<FilteredTouch>();
private List<FilteredTouch> currentTouches = new ArrayList<FilteredTouch>();
private List<FilteredTouch> touchesToRemoveFromCurrentTouches = new ArrayList<FilteredTouch>();
private List<FilteredTouch> touchesToAddToCurrentTouches = new ArrayList<FilteredTouch>();
private List<FilteredTouch> recentlyLiftedTouches = new ArrayList<FilteredTouch>();
private List<FilteredTouch> touchesToRemoveFromRecentlyLiftedTouches = new ArrayList<FilteredTouch>();


void touchDown(Touch touch) {
    PVector machinePosition = inputSpaceToMachineSpace(new PVector(touch.x, touch.y));
    logEvent(new HybridRawTouchDownEvent(touch.cursorID, machinePosition.x, machinePosition.y));
    // If these conditions are not met, the touch will never be added to
    // currentTouches. It will be as a ghost. :(. The rest of the code should
    // take care not to assume that simply because a touch is registered by the
    // driver, that there has ever been a corresponding touch in currentTouches.
    if (machinePosition.x > IGNORE_BORDER && machinePosition.x < machineScreenWidth - IGNORE_BORDER) {
        if (machinePosition.y > IGNORE_BORDER && machinePosition.y < machineScreenHeight - IGNORE_BORDER) {
            for (FilteredTouch filteredTouch: currentTouches) {
                float distanceX = filteredTouch.rawX - machinePosition.x;
                float distanceY = filteredTouch.rawY - machinePosition.y;
                float distance2 = distanceX * distanceX + distanceY * distanceY;
                if (distance2 <= filteredTouch.touchDownDistanceThreshold * filteredTouch.touchDownDistanceThreshold) {
                    // This touch was close enough to an existing touch that we'll just absorb it.
                    filteredTouch.absorbed.add(touch.cursorID);
                    return;
                }
            }
            currentTouches.add(new FilteredTouch(touch.cursorID,
                                                 System.currentTimeMillis(),
                                                 0,
                                                 machinePosition.x,
                                                 machinePosition.y));
        }
    }
}


void touchMoved(Touch touch) {
    PVector m = inputSpaceToMachineSpace(new PVector(touch.x, touch.y));
    logEvent(new HybridRawTouchMoveEvent(touch.cursorID, m.x, m.y));
    for (FilteredTouch filteredTouch: currentTouches) {
        for (Object absorbedIdObject: filteredTouch.absorbed) {
            int absorbedId = ((Integer) absorbedIdObject).intValue();
            if (absorbedId == ((Integer) filteredTouch.absorbed.get(0)).intValue()) {
                // We don't want to be able to split off from the controlling TUIO touch.
                continue;
            }
            if (absorbedId == touch.cursorID) {
                PVector machinePosition = inputSpaceToMachineSpace(new PVector(touch.x, touch.y));
                float distanceX = filteredTouch.rawX - machinePosition.x;
                float distanceY = filteredTouch.rawY - machinePosition.y;
                float distance2 = distanceX * distanceX + distanceY * distanceY;
                if (distance2 > filteredTouch.touchDownDistanceThreshold * filteredTouch.touchDownDistanceThreshold) {
                    // This touch moved far enough away from the touch into which it was
                    // absorbed that we will split off and make a new touch.
                    //
                    // An Integer box here, because Java is super smart with method
                    // overloading and uses remove(int) to remove at an index and
                    // remove(Object) to remove a specific entry, which in this case
                    // are the same thing. Good god.
                    filteredTouch.absorbed.remove(Integer.valueOf(touch.cursorID));
                    currentTouches.add(new FilteredTouch(touch.cursorID,
                                                         System.currentTimeMillis(),
                                                         0,
                                                         machinePosition.x,
                                                         machinePosition.y));
                    return;
                }
            }
        }
        if (((Integer) filteredTouch.absorbed.get(0)).intValue() == touch.cursorID) {
            PVector machinePosition = inputSpaceToMachineSpace(new PVector(touch.x, touch.y));
            filteredTouch.updatePosition(machinePosition.x, machinePosition.y);
            break;
        }
    }
}


void touchUp(Touch touch) {
    PVector m = inputSpaceToMachineSpace(new PVector(touch.x, touch.y));
    logEvent(new HybridRawTouchUpEvent(touch.cursorID, m.x, m.y));
    for (FilteredTouch filteredTouch: currentTouches) {
        boolean removed = filteredTouch.absorbed.remove(Integer.valueOf(touch.cursorID));
        if (removed && filteredTouch.absorbed.size() == 0) {
            PVector machinePosition = inputSpaceToMachineSpace(new PVector(touch.x, touch.y));
            filteredTouch.updatePosition(machinePosition.x, machinePosition.y);
            filteredTouch.touchUpTime = System.currentTimeMillis();
            recentlyLiftedTouches.add(filteredTouch);
            touchesToRemoveFromCurrentTouches.add(filteredTouch);
            break;
        }
    }
    for (FilteredTouch filteredTouch: touchesToRemoveFromCurrentTouches) {
        currentTouches.remove(filteredTouch);
    }
    touchesToRemoveFromCurrentTouches.clear();
}


private class Lowpass {
    float previous;
    boolean initialized;
    Lowpass() {
        this.initialized = false;
    }
    float filter(float x, float alpha) {
        if (!initialized) {
            this.initialized = true;
            this.previous = x;
        }
        float result = alpha * x + (1 - alpha) * this.previous;
        this.previous = result;
        return result;
    }
}


private class OneEuro {
    boolean initialized;
    Lowpass xFilter;
    Lowpass dxFilter;
    float refreshRate;
    float minCutoff;
    float beta;
    float dCutoff;
    OneEuro(float refreshRate, float minCutoff, float beta, float dCutoff) {
        this.initialized = false;
        this.xFilter = new Lowpass();
        this.dxFilter = new Lowpass();
        this.refreshRate = refreshRate;
        this.minCutoff = minCutoff;
        this.beta = beta;
        this.dCutoff = dCutoff;
    }
    float alpha(float refreshRate, float lowpassCutoff) {
        return (float) (1.0 / (1.0 + (refreshRate / (2 * Math.PI * lowpassCutoff))));
    }
    float filter(float x) {
        float dx;
        if (this.initialized) {
            dx = (x - this.xFilter.previous) * this.refreshRate;
        } else {
            this.initialized = true;
            dx = 0;
        }
        float edx = this.dxFilter.filter(dx, this.alpha(this.refreshRate, this.dCutoff));
        float cutoff = this.minCutoff + this.beta * Math.abs(edx);
        return this.xFilter.filter(x, this.alpha(this.refreshRate, cutoff));
    }
    void reinitialize() {
        this.initialized = false;
        this.xFilter.initialized = false;
        this.dxFilter.initialized = false;
    }
}
