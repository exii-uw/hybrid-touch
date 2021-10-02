
import vialab.SMT.*;


// FSM:
//                  .----3-finger touch in CURSOR mode----.
//                  |                                     v
//           [ABSOLUTE]                                 [RELATIVE_AWAITING_CURSOR]
//               ^  ^                                     |        |
//               |  '----------all fingers lifted---------'        |
//               |                                                 |
//            timeout                                     finger moved quickly
//               |                                                 |
//               |                                                 v
//        [ABSOLUTE_WAIT]<-----all fingers lifted-------[RELATIVE_CURSOR_SPAWNED]


private class InteractionState { }
private final InteractionState INTERACTIONSTATE_ABSOLUTE = new InteractionState();
private final InteractionState INTERACTIONSTATE_RELATIVE_AWAITING_CURSOR = new InteractionState();
private final InteractionState INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED = new InteractionState();
private final InteractionState INTERACTIONSTATE_ABSOLUTE_WAIT = new InteractionState();


private final int CURSOR_SPAWN_FINGER_COUNT = 3; // How many fingers are needed to spawn a cursor in CURSOR mode
private final float CURSOR_SPAWN_VELOCITY_THRESHOLD = 4.0; // Movement threshold to spawn a cursor at a specific finger


private final int ABSOLUTE_WAIT_FRAMES = 10; // How long to wait in ABSOLUTE_WAIT state


// For some reason, while using the cursor-based interaction modes, a lot of taps are registered
// underneath the inactive hand (powerwall nonsense). So we create a dead zone around all fingers
// that spawned the cursor without controlling it, so that this doesn't happen. The dead zone is
// lifted when the cursor is despawned. The dead zone applies only to tap detection -- all other
// forms of touch detection are unaffected.
// In addition, any finger responsible for spawning a dead zone will never be responsible for a
// tap. Just as insurance.
private final float DEAD_ZONE_RADIUS_MOVING = 512.0; // How large dead zones are when fingers are moving
private final float DEAD_ZONE_RADIUS_STILL = 96.0; // How large dead zones are when fingers are still
private final float DEAD_ZONE_VELOCITY_FADE = 0.95; // Friction on dead zone sliding when finger is released
private final float DEAD_ZONE_VELOCITY_PULL_VALUE = 18.0; // Speed that makes the dead zone use the PULL size
private final float DEAD_ZONE_VELOCITY_RADIUS_FADE = 0.9; // How quickly the dead zone radius approaches its value
private final int DEAD_ZONE_TIMEOUT = 24; // How long after a finger is lifted before the dead zone leaves
private final float TOUCH_DOWN_DISTANCE_THRESHOLD_CURSOR = 256; // Increase touch merge size for the cursor finger

private class DeadZoneMode { }
private final DeadZoneMode DEAD_ZONE_MODE_INDIVIDUAL_FINGERS = new DeadZoneMode();
private final DeadZoneMode DEAD_ZONE_MODE_ENCLOSING_CIRCLE = new DeadZoneMode();
private final float DEAD_ZONE_ENCLOSING_CIRCLE_MAXIMUM_DISTANCE = 256.0; // Maximum diameter of dead zone
private final float DEAD_ZONE_ENCLOSING_CIRCLE_MINIMUM_SIZE = DEAD_ZONE_RADIUS_STILL * 4; // Minimum size

private final long DEAD_ZONE_TOUCH_TAP_TIME_THRESHOLD = (long) (TOUCH_TAP_TIME_THRESHOLD * 1.5);

private final boolean DEAD_ZONE_MOVE_WITH_FINGERS = false; // Whether or not moving fingers should change the dead zone
private final boolean DEAD_ZONE_MOVE_WITH_DEAD_FINGERS = true; // Only dead fingers


abstract class InteractionListener {
    /**
     * Acknowledge that a click has happened at the given point, whether by
     * finger or by cursor.
     * @param x                 x-coordinate of the touch
     * @param y                 y-coordinate of the touch
     * @param registerClickType the event that caused the touch
     * @param touchId           the finger that caused the touch, if relevant
     * @param startTime         when the finger went down (to ignore touches)
     */
    abstract void click(float x, float y, String registerClickType, int touchId, long startTime);

    /**
     * Acknowledge that a cursor was tapped at the given point.
     * @param x                 x-coordinate of the touch
     * @param y                 y-coordinate of the touch
     */
    abstract void cursorTap(float x, float y);

    /**
     * Acknowledge that a cursor was created at the given point.
     * @param x                 x-coordinate of the touch
     * @param y                 y-coordinate of the touch
     */
    abstract void cursorSpawn(float x, float y);

    /**
     * Acknowledge that cursor movement occurred at the given point.
     * @param x                 x-coordinate of the touch
     * @param y                 y-coordinate of the touch
     */
    abstract void cursorMove(float x, float y);

    /**
     * Acknowledge that the cursor despawned at the given point.
     * @param x                 x-coordinate of the touch
     * @param y                 y-coordinate of the touch
     */
    abstract void cursorDespawn(float x, float y);

    /**
     * Return the name of the participant using this interaction machine.
     */
    abstract String participant();


    /**
     * Return all of the touches that are owned by the interaction's workspace.
     */
    abstract List<FilteredTouch> getFilteredTouches();
}


/**
 * A finite state machine tracking a single interaction space.
 */
class InteractionMachine {
    private InteractionState interactionState = INTERACTIONSTATE_ABSOLUTE;
    private InteractionListener listener;
    private float cursorX = 0.0; // X location of cursor
    private float cursorY = 0.0; // Y location of cursor
    private float cursorOriginX = 0.0; // X location where cursor was spawned (for halo size)
    private float cursorOriginY = 0.0; // Y location where cursor was spawned (for halo size)
    private float cursorVelocityX = 0.0;
    private float cursorVelocityY = 0.0;
    private float cursorMaxSpeedSquared = 0.0;
    private int absoluteWaitFrames = 0; // Counts down from ABSOLUTE_WAIT_FRAMES to zero
    private List<DeadZone> deadZones = new ArrayList<DeadZone>();
    private List<DeadZone> deadZonesToRemove = new ArrayList<DeadZone>();
    private List<DeadFinger> deadFingers = new ArrayList<DeadFinger>();
    private List<DeadFinger> deadFingersToRemove = new ArrayList<DeadFinger>();
    private DeadZoneMode deadZoneMode = DEAD_ZONE_MODE_ENCLOSING_CIRCLE;
    private List<Integer> deadZoneTouchTapFingers = new ArrayList<Integer>();
    private long deadZoneTouchTapTimeStart = 0;
    // private float estimatedParticipantX = 0.0; // Estimated location of the participant while using cursor
    // private float estimatedParticipantY = 0.0;


    private HashMap<Integer, Float> touchDistances = new HashMap();
    private ArrayList<PVector> pointsToEnclose = new ArrayList<PVector>();


    public InteractionMachine(InteractionListener listener) {
        this.listener = listener;
    }


    /**
     * Draw the current interaction state. Currently, this simply draws the cursor
     * if one has been spawned.
     */
    void displayInteraction() {
        if (interactionState == INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED) {
            PVector distance = new PVector(cursorX - cursorOriginX, cursorY - cursorOriginY);
            float distanceMagnitude = distance.mag() / ((machineScreenWidth + machineScreenHeight) / 2);
            displayCursor(cursorX, cursorY, distanceMagnitude);
        }
    }


    /**
     * Draw the current interaction state debug information.
     */
    void displayInteractionDeadZones() {
        for (DeadZone deadZone: deadZones) {
            displayDebugDeadZone(deadZone.x, deadZone.y, deadZone.radius, (float) deadZone.life / (float) DEAD_ZONE_TIMEOUT);
        }
    }


    /**
     * Update touch behaviours.
     */
    void updateInteraction() {
        if (interactionState == INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED) {
            float distanceX = cursorX - cursorOriginX;
            float distanceY = cursorY - cursorOriginY;
            float distance = (float) Math.sqrt(distanceX * distanceX + distanceY * distanceY);
            float velocityX = cursorVelocityX;
            float velocityY = cursorVelocityY;
            float speed = (float) Math.sqrt(velocityX * velocityX + velocityY * velocityY);
            if (speed > 0) {
                velocityX /= speed;
                velocityY /= speed;
            }
            float maxSpeed = (float) Math.sqrt(cursorMaxSpeedSquared);
            float mappedSpeed = cursorVelocityCurve(maxSpeed, distance);
            velocityX *= mappedSpeed;
            velocityY *= mappedSpeed;
            cursorX += velocityX;
            cursorY += velocityY;
            cursorVelocityX = 0.0;
            cursorVelocityY = 0.0;
            cursorMaxSpeedSquared = 0.0;
            this.listener.cursorMove(cursorX, cursorY);
            logEvent(new HybridCursorMovedEvent(this.listener.participant(), cursorX, cursorY));
        }


        if (interactionState == INTERACTIONSTATE_ABSOLUTE_WAIT) {
            if (absoluteWaitFrames > 0) {
                absoluteWaitFrames -= 1;
            } else {
                interactionState = INTERACTIONSTATE_ABSOLUTE;
            }
        }


        for (DeadZone deadZone: deadZones) {
            deadZone.update();
            logEvent(new HybridDeadZoneChangedEvent(deadZone.id, deadZone.x, deadZone.y, deadZone.radius));
            if (deadZone.shouldBeRemoved()) {
                deadZonesToRemove.add(deadZone);
            }
        }
        for (DeadZone deadZone: deadZonesToRemove) {
            deadZones.remove(deadZone);
            logEvent(new HybridDeadZoneDespawnedEvent(deadZone.id));
        }
        deadZonesToRemove.clear();
        for (DeadFinger deadFinger: deadFingers) {
            if (deadFinger.shouldBeRemoved()) {
                deadFingersToRemove.add(deadFinger);
            }
        }
        for (DeadFinger deadFinger: deadFingersToRemove) {
            deadFingers.remove(deadFinger);
        }
        deadFingersToRemove.clear();
    }


    /**
     * Return the number of touches onscreen.
     */
    private int activeTouches() {
        return listener.getFilteredTouches().size();
    }


    /**
     * Return the number of touches onscreen that aren't in dead zones or triggered
     * by dead fingers.
     */
    private int nonDeadTouches() {
        int nonDeadTouches = 0;
        for (FilteredTouch touch: listener.getFilteredTouches()) {
            if (touchIsDead(touch)) {
                continue;
            }
            ++nonDeadTouches;
        }
        return nonDeadTouches;
    }


    /**
     * Return the number of touches onscreen that are in dead zones or are
     * triggered by dead fingers.
     */
    private int deadTouches() {
        return activeTouches() - nonDeadTouches();
    }


    /**
     * Return true if this touch is inside a dead zone or was killed.
     */
    private boolean touchIsDead(FilteredTouch touch) {
        if (touchIsCurrentlyInDeadZone(touch)) {
            return true;
        }
        if (fingerIsDead(touch)) {
            return true;
        }
        return false;
    }


    /**
     * Return true if this touch was killed.
     */
    private boolean fingerIsDead(FilteredTouch touch) {
        for (DeadFinger finger: deadFingers) {
            if (finger.id == touch.id) {
                return true;
            }
        }
        return false;
    }


    /**
     * Return true if this touch is inside a dead zone.
     */
    private boolean touchIsCurrentlyInDeadZone(FilteredTouch touch) {
        for (DeadZone deadZone: deadZones) {
            if (deadZone.touchContained(touch.x, touch.y)) {
                return true;
            }
        }
        return false;
    }


    /**
     * Called when a new touch is placed onscreen.
     */
    void touchDown(FilteredTouch touch) {
        logEvent(new HybridTouchDownEvent(touch.id, touch.x, touch.y));
        // We allow for interaction modes to be entered even during the absolute
        // waiting period because it supports clutching better. There's already
        // a good amount of delay on the filtered touch input as-is. We still
        // don't allow taps during the timeout, though.
        if (interactionState == INTERACTIONSTATE_ABSOLUTE || interactionState == INTERACTIONSTATE_ABSOLUTE_WAIT) {
            if (activeTouches() >= CURSOR_SPAWN_FINGER_COUNT) {
                interactionState = INTERACTIONSTATE_RELATIVE_AWAITING_CURSOR;
            }
        }
        if (interactionState == INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED) {
            if (touchIsCurrentlyInDeadZone(touch)) {
                if (deadZoneTouchTapFingers.isEmpty()) {
                    deadZoneTouchTapTimeStart = touch.touchDownTime;
                }
                deadZoneTouchTapFingers.add(touch.id);
            }
        }
    }


    /**
     * Called when any touch is lifted. The touch will have already been removed
     * from the currently active touches.
     */
    void touchUp(FilteredTouch touch) {
        logEvent(new HybridTouchUpEvent(touch.id, touch.x, touch.y));
        for (DeadFinger deadFinger: deadFingers) {
            if (deadFinger.id == touch.id) {
                deadFinger.kill();
            }
        }
        if (interactionState == INTERACTIONSTATE_RELATIVE_AWAITING_CURSOR) {
            if (activeTouches() == 0) {
                absoluteWaitFrames = ABSOLUTE_WAIT_FRAMES;
                interactionState = INTERACTIONSTATE_ABSOLUTE_WAIT;
            }
        } else if (interactionState == INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED) {
            if (activeTouches() == 0) {
                for (DeadZone deadZone: deadZones) {
                    logEvent(new HybridDeadZoneKilledEvent(deadZone.id));
                    deadZone.kill();
                }
                absoluteWaitFrames = ABSOLUTE_WAIT_FRAMES;
                interactionState = INTERACTIONSTATE_ABSOLUTE_WAIT;
                this.listener.cursorDespawn(cursorX, cursorY);
                logEvent(new HybridCursorDespawnedEvent(this.listener.participant()));
            }
        }
        deadZoneTouchTapFingers.remove(new Integer(touch.id));
    }


    /**
     * Called when any touch is moved, regardless of whether or not it is still
     * eligible to trigger a touch-tap.
     */
    void touchMove(FilteredTouch touch) {
        logEvent(new HybridTouchMoveEvent(touch.id, touch.x, touch.y));
        if (deadZoneMode == DEAD_ZONE_MODE_ENCLOSING_CIRCLE
                && interactionState == INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED) {
            if ((touchIsDead(touch) && DEAD_ZONE_MOVE_WITH_FINGERS)
             || (fingerIsDead(touch) && DEAD_ZONE_MOVE_WITH_DEAD_FINGERS)) {
                // Move the enclosing dead zone by however much this finger moved divided by
                // the number of dead touches (added up across all touchMove events, this
                // will be the mean of the fingers' movements.) Then, resize the enclosing
                // dead zone to make sure that it continues to contain every finger that
                // started in the dead zone or was killed.
                int deadTouchCount = DEAD_ZONE_MOVE_WITH_FINGERS ? deadTouches() : deadFingers.size();
                float deltaX = touch.xVelocity / deadTouchCount;
                float deltaY = touch.yVelocity / deadTouchCount;
                // There should really only be one dead zone, but whatever.
                for (DeadZone deadZone: deadZones) {
                    deadZone.x += deltaX;
                    deadZone.y += deltaY;
                    // Resize the dead zone.
                    float greatestDistanceFromCenterSquared = 0.0;
                    for (FilteredTouch otherTouch: listener.getFilteredTouches()) {
                        if (DEAD_ZONE_MOVE_WITH_FINGERS ? touchIsDead(otherTouch) : fingerIsDead(otherTouch)) {
                            float distanceX = otherTouch.x - deadZone.x;
                            float distanceY = otherTouch.y - deadZone.y;
                            float distanceSquared = distanceX * distanceX + distanceY * distanceY;
                            if (distanceSquared > greatestDistanceFromCenterSquared) {
                                greatestDistanceFromCenterSquared = distanceSquared;
                            }
                        }
                    }
                    float greatestDistanceFromCenter = ((float) Math.sqrt(greatestDistanceFromCenterSquared))
                        + DEAD_ZONE_RADIUS_STILL;
                    if (greatestDistanceFromCenter < DEAD_ZONE_ENCLOSING_CIRCLE_MINIMUM_SIZE) {
                        greatestDistanceFromCenter = DEAD_ZONE_ENCLOSING_CIRCLE_MINIMUM_SIZE;
                    }
                    deadZone.radius = greatestDistanceFromCenter;
                    logEvent(new HybridDeadZoneChangedEvent(deadZone.id, deadZone.x, deadZone.y, deadZone.radius));
                }
            }
        } else if (deadZoneMode == DEAD_ZONE_MODE_INDIVIDUAL_FINGERS) {
            if (touchIsDead(touch)) {
                for (DeadZone deadZone: deadZones) {
                    if (deadZone.id == touch.id) {
                        deadZone.x = touch.x;
                        deadZone.y = touch.y;
                        deadZone.xVelocity = touch.xVelocity;
                        deadZone.yVelocity = touch.yVelocity;
                        logEvent(new HybridDeadZoneChangedEvent(deadZone.id, deadZone.x, deadZone.y, deadZone.radius));
                    }
                }
            }
        }
    }


    /**
     * Called when a touch is moved, and that touch has existed long enough that
     * it cannot trigger a touch-tap. Used so that taps don't move the cursor.
     */
    void touchSignificantMove(FilteredTouch touch) {
        PVector velocity = new PVector(touch.xVelocity, touch.yVelocity);
        if (interactionState == INTERACTIONSTATE_RELATIVE_AWAITING_CURSOR
                && velocity.mag() > CURSOR_SPAWN_VELOCITY_THRESHOLD) {
            List<FilteredTouch> touches = listener.getFilteredTouches();
            List<FilteredTouch> deadTouches = new ArrayList(touches);

            // The user might lift their fingers during RELATIVE_AWAITING_CURSOR.
            if (touches.size() < CURSOR_SPAWN_FINGER_COUNT) {
                interactionState = INTERACTIONSTATE_ABSOLUTE;
                return;
            }

            // Remove whichever touch is furthest away from every other touch.
            // This is the instigating touch.
            float maximumDistance = -1.0;
            FilteredTouch maximumDistanceTouch = null;
            for (FilteredTouch otherTouch: touches) {
                float distance = 0.0;
                for (FilteredTouch otherOtherTouch: touches) {
                    if (otherTouch.id == otherOtherTouch.id) {
                        continue;
                    }
                    float distanceX = otherTouch.x - otherOtherTouch.x;
                    float distanceY = otherTouch.y - otherOtherTouch.y;
                    distance += Math.sqrt(distanceX * distanceX + distanceY * distanceY);
                }
                if (distance > maximumDistance) {
                    maximumDistance = distance;
                    maximumDistanceTouch = otherTouch;
                }
            }
            deadTouches.remove(maximumDistanceTouch);

            // Continue removing touches until we can reduce the radius of the
            // dead zone to the maximum distance. We do this by checking every
            // pair of touches for the distance between them. Whichever pair
            // of touches has the largest distance between them, one of the
            // two is removed from the dead zone. The one that's removed is
            // whichever one has the largest average distance to every other
            // touch.
            touchDistances.clear();
            while (deadTouches.size() > 1) {
                maximumDistance = -1.0;
                FilteredTouch maximumDistanceTouchP1 = null;
                FilteredTouch maximumDistanceTouchP2 = null;
                for (FilteredTouch otherTouch: deadTouches) {
                    float totalDistance = 0.0;
                    for (FilteredTouch otherOtherTouch: deadTouches) {
                        if (otherTouch.id == otherOtherTouch.id) {
                            continue;
                        }
                        float distanceX = otherTouch.x - otherOtherTouch.x;
                        float distanceY = otherTouch.y - otherOtherTouch.y;
                        float thisDistance = (float) Math.sqrt(distanceX * distanceX + distanceY * distanceY);
                        if (thisDistance > maximumDistance) {
                            maximumDistance = thisDistance;
                            maximumDistanceTouchP1 = otherTouch;
                            maximumDistanceTouchP2 = otherOtherTouch;
                        }
                        totalDistance += thisDistance;
                    }
                    touchDistances.put(otherTouch.id, totalDistance);
                }
                if (maximumDistance > DEAD_ZONE_ENCLOSING_CIRCLE_MAXIMUM_DISTANCE &&
                        maximumDistanceTouchP1 != null &&
                        maximumDistanceTouchP2 != null) {
                    float distanceP1 = ((Float) touchDistances.get(maximumDistanceTouchP1.id)).floatValue();
                    float distanceP2 = ((Float) touchDistances.get(maximumDistanceTouchP2.id)).floatValue();
                    if (distanceP1 > distanceP2) {
                        deadTouches.remove(maximumDistanceTouchP1);
                    } else {
                        deadTouches.remove(maximumDistanceTouchP2);
                    }
                } else {
                    break;
                }
            }

            // If we got down to here, it means that we removed dead touches
            // until the pairwise distance between any two points in the dead
            // zone was at most the maximum dead zone size. This will (hopefully...?)
            // happen eventually, once the dead zone is reduced to a single finger
            // in the worst case.
            if (deadTouches.size() == 0) {
                println("Warning: deadTouches has zero size!");
            }

            // Now, we have to actually create the dead zone around them.

            deadZoneTouchTapTimeStart = touch.touchDownTime;
            if (deadZoneMode == DEAD_ZONE_MODE_INDIVIDUAL_FINGERS) {
                for (FilteredTouch otherTouch: deadTouches) {
                    // Just add a dead zone for each dead finger.
                    DeadZone deadZone = new DeadZone(otherTouch.id,
                                                     otherTouch.x,
                                                     otherTouch.y,
                                                     DEAD_ZONE_RADIUS_STILL,
                                                     false);
                    deadZones.add(deadZone);
                    logEvent(new HybridDeadZoneSpawnedEvent(deadZone.id, deadZone.x, deadZone.y, deadZone.radius));
                    deadFingers.add(new DeadFinger(otherTouch.id));
                    logEvent(new HybridFingerKilledEvent(otherTouch.id));
                    deadZoneTouchTapFingers.add(otherTouch.id);
                }
            } else if (deadZoneMode == DEAD_ZONE_MODE_ENCLOSING_CIRCLE) {
                pointsToEnclose.clear();
                for (FilteredTouch otherTouch: deadTouches) {
                    // Kill fingers and add them to the touch tap list, as usual.
                    deadFingers.add(new DeadFinger(otherTouch.id));
                    logEvent(new HybridFingerKilledEvent(otherTouch.id));
                    deadZoneTouchTapFingers.add(otherTouch.id);

                    // Add every finger to a list of dead fingers, which will
                    // be used to compute an enclosing circle.
                    pointsToEnclose.add(new PVector(otherTouch.x, otherTouch.y));
                }
                // Compute the center of a circle enclosing all the points. We
                // move all the points away from their median by the static dead
                // zone radius to make the computed dead zone a bit bigger.
                PVector max = pointsToEnclose.get(0).get();
                PVector min = pointsToEnclose.get(0).get();
                for (PVector point: pointsToEnclose) {
                    if (point.x > max.x) max.x = point.x;
                    if (point.y > max.y) max.y = point.y;
                    if (point.x < min.x) min.x = point.x;
                    if (point.y < min.y) min.y = point.y;
                }
                // Ok, technically this is the centre of a bounding box containing every
                // point, but whatever.
                PVector median = new PVector((max.x + min.x) * 0.5, (max.y + min.y) * 0.5);
                float furthestDistanceToMedian = DEAD_ZONE_ENCLOSING_CIRCLE_MINIMUM_SIZE;
                for (PVector point: pointsToEnclose) {
                    PVector awayFromMedian = PVector.sub(point, median);
                    awayFromMedian.setMag(DEAD_ZONE_RADIUS_STILL);
                    point.add(awayFromMedian);
                    float distanceToMedian = point.dist(median);
                    if (distanceToMedian > furthestDistanceToMedian) furthestDistanceToMedian = distanceToMedian;
                }
                // The touch ID of this dead zone doesn't matter, since the dead zone
                // will be moved and resized by the actions of every finger.
                DeadZone deadZone = new DeadZone(0, median.x, median.y, furthestDistanceToMedian, false);
                deadZones.add(deadZone);
                logEvent(new HybridDeadZoneSpawnedEvent(deadZone.id, deadZone.x, deadZone.y, deadZone.radius));
            }

            // Estimate the position of the user from the centre of the bounding box
            // of every touch.
            /*float minFingerX = machineScreenWidth;
            float minFingerY = machineScreenHeight;
            float maxFingerX = 0.0;
            float maxFingerY = 0.0;
            for (FilteredTouch otherTouch: touches) {
                if (otherTouch.x < minFingerX) minFingerX = otherTouch.x;
                if (otherTouch.y < minFingerY) minFingerY = otherTouch.y;
                if (otherTouch.x > maxFingerX) maxFingerX = otherTouch.x;
                if (otherTouch.y > maxFingerY) maxFingerY = otherTouch.y;
            }
            estimatedParticipantX = (minFingerX + maxFingerX) * 0.5;
            estimatedParticipantY = (minFingerY + maxFingerY) * 0.5;
            logEvent(new HybridParticipantLocationEstimatedEvent(estimatedParticipantX, estimatedParticipantY));*/

            // Determine where the cursor will spawn, and create it.
            int instigatingTouches = 0;
            cursorOriginX = 0.0;
            cursorOriginY = 0.0;
            for (FilteredTouch otherTouch: touches) {
                if (!deadTouches.contains(otherTouch)) {
                    ++instigatingTouches;
                    cursorOriginX += otherTouch.x;
                    cursorOriginY += otherTouch.y;
                }
            }
            if (instigatingTouches == 0) {
                // This should never happen, because we always remove the furthest
                // finger from the set of dead fingers.
                println("Warning: dead zone contains every finger, so cursor cannot be spawned!");
                return;
            }
            cursorOriginX /= (float) instigatingTouches;
            cursorOriginY /= (float) instigatingTouches;
            cursorX = cursorOriginX;
            cursorY = cursorOriginY;

            interactionState = INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED;
            this.listener.cursorSpawn(cursorX, cursorY);
            logEvent(new HybridCursorSpawnedEvent(this.listener.participant(),
                                                  touch.id,
                                                  listener.getFilteredTouches().size(),
                                                  cursorOriginX,
                                                  cursorOriginY));

        } else if (interactionState == INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED) {
            if (touchIsDead(touch)) {
                return;
            }
            int aliveFingerCount = nonDeadTouches();
            // aliveFingerCount must be at least 1 now, otherwise we would have returned
            // on account of the current finger. I hope.

            // Modify the radius in which touches can be considered continuations, to reduce
            // spurious touch taps.
            touch.touchDownDistanceThreshold = (float) Math.max(TOUCH_DOWN_DISTANCE_THRESHOLD_CURSOR,
                    Math.sqrt(touch.xVelocity * touch.xVelocity + touch.yVelocity * touch.yVelocity) * 1.1);

            // Finally, add the velocity of the current touch to the cursor's velocity. This
            // will determine the direction of the cursor's movement.
            cursorVelocityX += touch.xVelocity;
            cursorVelocityY += touch.yVelocity;

            float touchSpeed = touch.xVelocity * touch.xVelocity + touch.yVelocity * touch.yVelocity;
            if (touchSpeed > cursorMaxSpeedSquared) {
                cursorMaxSpeedSquared = touchSpeed;
            }
        }
    }


    /**
     * Called when a touch is lifted after being initiated no longer than a
     * certain amount of time ago, after having moved no further than a specific
     * distance, as defined in filter.pde. The touch will already have been removed
     * from the currently active touches.
     */
    void touchTap(FilteredTouch touch) {
        if (touchIsDead(touch)) {
            return;
        }
        if (interactionState == INTERACTIONSTATE_ABSOLUTE) {
            if (activeTouches() == 0) {
                this.listener.click(touch.x, touch.y, "Finger", touch.id, touch.touchDownTime);
                absoluteWaitFrames = ABSOLUTE_WAIT_FRAMES;
                interactionState = INTERACTIONSTATE_ABSOLUTE_WAIT;
            }
        } else if (interactionState == INTERACTIONSTATE_RELATIVE_CURSOR_SPAWNED) {
            if (nonDeadTouches() == 0) {
                this.listener.click(cursorX, cursorY, "CursorTapped", touch.id, touch.touchDownTime);
                this.listener.cursorTap(cursorX, cursorY);
            }
        }
    }
}


/**
 * Calculate a sigmoid curve based on the given parameters. The curve is equal
 * to zero at x=0, and eases into a logistic curve raised to a power. We also
 * take the maximum of the curve and the input, so that the cursor never moves
 * any slower than the user's input.
 * @param L the sigmoid's maximum value
 * @param k the sigmoid's steepness
 * @param T the tension of the curve.
 * @param x0 the x-value of the sigmoid's midpoint
 * @param x1 the x-value where the linear interpolation from zero to logistic is fully logistic.
 * @param x the point on the curve to evaluate.
 */
private float sigmoid(float L, float k, float T, float x0, float x1, float x) {
    float t = x / x1;
    if (t > 1) { t = 1; }
    if (t < 0) { t = 0; }
    return Math.max(L * t * (float) Math.pow(1 / (1 + (float) Math.exp(-k * (x - x0))), T), x);
}


/**
 * Maps the touch-move velocity reported by the input to cursor velocity in screen-space.
 * @param input the speed the user is moving their finger
 * @param distance the distance the cursor currently is from the cursor's original position
 * @return the speed the cursor should move in the direction of the finger's movement
 */
private float cursorVelocityCurve(float input, float distance) {
    return sigmoid(240 * machineVelocityScale, 0.2, 0.8, 20.0, 4.0, input);
}


class DeadZone {
    int id;
    float x;
    float y;
    float radius;
    boolean resizes;
    float xVelocity;
    float yVelocity;
    float minRadius;
    float radiusDelta;
    int life;
    boolean killed;
    DeadZone(int id, float x, float y, float radius, boolean resizes) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.radius = radius;
        this.resizes = resizes;
        this.xVelocity = 0.0;
        this.yVelocity = 0.0;
        this.minRadius = DEAD_ZONE_RADIUS_STILL;
        this.radiusDelta = radius - this.minRadius;
        this.life = DEAD_ZONE_TIMEOUT;
        this.killed = false;
    }
    void update() {
        if (this.resizes) {
            float speedSquared = this.xVelocity * this.xVelocity + this.yVelocity * this.yVelocity;
            float speedParam = Math.min((float) Math.sqrt(speedSquared) / DEAD_ZONE_VELOCITY_PULL_VALUE, 1.0);
            float targetRadius = this.minRadius + speedParam * (this.radiusDelta);
            this.radius += (targetRadius - this.radius) * DEAD_ZONE_VELOCITY_RADIUS_FADE;
        }
        if (this.killed) {
            this.x += this.xVelocity;
            this.y += this.yVelocity;
            this.xVelocity *= DEAD_ZONE_VELOCITY_FADE;
            this.yVelocity *= DEAD_ZONE_VELOCITY_FADE;
            if (this.life > 0) {
                this.life -= 1;
            }
        }
    }
    void kill() {
        this.killed = true;
    }
    boolean touchContained(float tx, float ty) {
        float dx = (tx - this.x);
        float dy = (ty - this.y);
        return dx * dx + dy * dy <= this.radius * this.radius;
    }
    boolean shouldBeRemoved() {
        return this.life == 0;
    }
}


class DeadFinger {
    int id;
    boolean killed;
    DeadFinger(int id) {
        this.id = id;
        this.killed = false;
    }
    void kill() {
        this.killed = true;
    }
    boolean shouldBeRemoved() {
        return this.killed;
    }
}
