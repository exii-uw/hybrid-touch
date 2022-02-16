import ddf.minim.spi.*;
import ddf.minim.signals.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;
import ddf.minim.effects.*;

import java.util.*;

final String  CONFIG_SCRIPT = "scripts/october/P8.csv";
final boolean CONFIG_TARGET_PRACTICE = true; // Allow user to practice interaction technique
final boolean CONFIG_SHOW_DEBUG_TOUCHES = false; // Display the position of touches and filters
final boolean CONFIG_SHOW_USER_TOUCHES = true; // Display the position of filtered touches only
final boolean CONFIG_SHOW_DEAD_ZONES = true; // Display the touch dead zones
final boolean CONFIG_SHOW_DEBUG_PARTICIPANT = false; // Display the estimated participant location
final boolean CONFIG_HYPERTAP = false; // Tap the targets for me, dammit, I'm a busy man
final boolean CONFIG_SUPERTAP = false; // Tap the targets for me, but gently
final boolean CONFIG_EXPERT_MODE = false; // I know how to do all this stuff.
// Set this to a valid path, and the script will fast-forward to the next ShowDiscardedTarget
// event and resume logging to this file.
final String  CONFIG_RESUME_LOG = null;
// Set this to a valid path, and the script will, instead of running a trial, play back the
// results of the given trial.
final String  CONFIG_PLAYBACK_LOG = null;
final float   CONFIG_PLAYBACK_SPEED = 2.0; // 2.0 is double speed, etc.
// Set this to a nonzero value to start the playback at a specific timestamp in the log.
final long    CONFIG_PLAYBACK_START_TIMESTAMP = 0;


long time = 0;
boolean multipleInteractionModes = false;


boolean discardTarget = false;
Target activeTarget = new Target(0, 0, 0, 0, false, 0);
TargetIndicator targetIndicators[] = new TargetIndicator[] {
    new TargetIndicator(0, 0, 0, 0, 0),
    new TargetIndicator(1, 0, 0, 0, 0),
    new TargetIndicator(2, 0, 0, 0, 0),
    new TargetIndicator(3, 0, 0, 0, 0)
};
StandingPositionIndicator standingPositionIndicator = new StandingPositionIndicator(0);


final float SCREEN_OFFSET_RESET_SPEED = 0.9; // How quickly to reset a pull back to zero
final float SCREEN_OFFSET_RESET_BUILDUP = 0.9;
float screenOffsetResetBuildup = 1.0;
boolean hadScreenOffsetResetThisFrame = false;
float screenOffsetX = 0; // The offset of the screen, for pull mode.
float screenOffsetY = 0; // The offset of the screen, for pull mode.


class TrialState { TrialState() { } }
final TrialState TRIALSTATE_DISPLAY_INTERACTION_MODE = new TrialState();
final TrialState TRIALSTATE_DISPLAY_TARGET_WIDTH = new TrialState();
final TrialState TRIALSTATE_DISPLAY_BIG_BLOCK = new TrialState();
final TrialState TRIALSTATE_TARGET_PRACTICE = new TrialState();
final TrialState TRIALSTATE_BREAK_THE_TARGETS = new TrialState();
final TrialState TRIALSTATE_THANK_YOU = new TrialState();
TrialState trialState;
boolean forceReset = false;


InteractionModeDialog interactionModeDialog;
TargetWidthDialog targetWidthDialog;
BigBlockDialog bigBlockDialog;
TargetPracticeDialog targetPracticeDialog;
ThankYouDialog thankYouDialog;


/**
 * Initialize the program.
 */
void init() {
    frame.removeNotify();
    frame.setUndecorated(true);
    frame.addNotify();
    super.init();
}


/**
 * Prepare the window.
 */
void setup() {
    initializeMachineSpecificParameters();
    smooth(4);
    size(machineScreenWidth, machineScreenHeight, SMT.RENDERER);
    SMT.init(this, TouchSource.AUTOMATIC);
    SMT.setTouchDraw(TouchDraw.NONE);
    colorMode(RGB, 255);
    background(0);
    strokeWeight(2);

    initializeSound();

    interactionModeDialog = new InteractionModeDialog();
    targetWidthDialog = new TargetWidthDialog();
    bigBlockDialog = new BigBlockDialog();
    targetPracticeDialog = new TargetPracticeDialog();
    thankYouDialog = new ThankYouDialog();
    if (CONFIG_PLAYBACK_LOG != null) {
        startPlayback(CONFIG_PLAYBACK_LOG, CONFIG_PLAYBACK_SPEED, CONFIG_PLAYBACK_START_TIMESTAMP);
    } else {
        loadScript(CONFIG_SCRIPT);
        if (CONFIG_RESUME_LOG != null) {
            // Start consuming events until we come up to the last
            // ShowDiscardedTarget event that was logged. Show that target,
            // then yield control to the user.
            disableLogging();
            consumeScript();
            enableLogging();
            initializeLogger(CONFIG_RESUME_LOG);
            logEvent(new HybridTrialResumedEvent());
        } else {
            // Start consuming events until we get to some point where control
            // should be yielded to the user.
            enableLogging();
            initializeLogger(CONFIG_RESUME_LOG);
            readScript();
        }
    }
}


/**
 * Stop the program.
 */
void stop() {
    stopSound();
}


/**
 * Acknowledge that a click has happened at the given point.
 * @param x                 x-coordinate of the touch
 * @param y                 y-coordinate of the touch
 * @param registerClickType the event that caused the touch
 * @param touchId           the finger that caused the touch, if relevant
 * @param startTime         when the finger went down (to ignore touches)
 */
void registerClick(float x, float y, String registerClickType, int touchId, long startTime) {
    createAnimation(new ClickAnimation(x, y));
    if (trialState == TRIALSTATE_BREAK_THE_TARGETS || trialState == TRIALSTATE_TARGET_PRACTICE) {
        if (startTime < activeTarget.spawnTime) {
            return;
        }
        if (activeTarget.click(x - screenOffsetX, y - screenOffsetY)) {
            playSoundTargetHit();
            if (trialState == TRIALSTATE_BREAK_THE_TARGETS) {
                if (!discardTarget) {
                    logEvent(new HybridTargetHitEvent(registerClickType,
                                touchId,
                                x,
                                y,
                                activeTarget.x,
                                activeTarget.y,
                                activeTarget.width,
                                activeTarget.height));
                }
                readScript();
            } else if (trialState == TRIALSTATE_TARGET_PRACTICE) {
                logEvent(new HybridTargetPracticeHitEvent(registerClickType, touchId, x, y,
                            activeTarget.x, activeTarget.y, activeTarget.width, activeTarget.height));
                activeTarget.placeRandomly();
                logEvent(new HybridTargetPracticeSpawnedEvent(activeTarget.x,
                            activeTarget.y,
                            activeTarget.width,
                            activeTarget.height));
            }
        } else {
            playSoundTargetMissed();
            if (trialState != TRIALSTATE_TARGET_PRACTICE && !discardTarget) {
                logEvent(new HybridTargetMissedEvent(registerClickType,
                            touchId,
                            x,
                            y,
                            activeTarget.x,
                            activeTarget.y,
                            activeTarget.width,
                            activeTarget.height));
            } else if (trialState == TRIALSTATE_TARGET_PRACTICE) {
                logEvent(new HybridTargetPracticeMissedEvent(registerClickType, touchId, x, y,
                            activeTarget.x, activeTarget.y, activeTarget.width, activeTarget.height));
            }
        }
    }
}


/**
 * Acknowledge a pull event.
 * @param x x velocity of the pull
 * @param y y velocity of the pull
 */
void registerPull(float x, float y) {
    screenOffsetX += x;
    screenOffsetY += y;
    logEvent(new HybridScreenPulledEvent(getFilteredTouches().size(), screenOffsetX, screenOffsetY));
}


/**
 * Acknowledge resetting the pull distance back to zero.
 */
void registerPullReset() {
    boolean logThis = Math.abs(screenOffsetX + screenOffsetY) > 0.0001;
    float speed = SCREEN_OFFSET_RESET_SPEED + (1 - SCREEN_OFFSET_RESET_SPEED) * screenOffsetResetBuildup;
    screenOffsetX *= speed;
    screenOffsetY *= speed;
    if (!hadScreenOffsetResetThisFrame) {
        screenOffsetResetBuildup *= SCREEN_OFFSET_RESET_BUILDUP;
        hadScreenOffsetResetThisFrame = true;
    }
    if (logThis) {
        logEvent(new HybridScreenResetEvent(screenOffsetX, screenOffsetY));
    }
}


/**
 * Skip script events to get back to where we left off. Used when
 * CONFIG_RESUME_LOG != null.
 */
void consumeScript() {
    assert CONFIG_RESUME_LOG != null;

    int skipForward = 0;
    String[] strings = loadStrings(CONFIG_RESUME_LOG);
    for (String line: strings) {
        if (line.contains("Trial.DiscardedTargetSpawned")) {
            ++skipForward;
        }
        if (line.contains("Trial.Ended")) {
            // Go to the readScript function to show the end-of-trial dialog
            // and exit.
            while (readNextScriptEvent() != null);
            readScript();
        }
    }

    ScriptEvent currentEvent;
    while ((currentEvent = readNextScriptEvent()) != null) {
        if (currentEvent.name.equals("Script.Start")) {
            handleScriptStart(currentEvent);
        } else if (currentEvent.name.equals("Script.InteractionMode")) {
            handleScriptInteractionMode(currentEvent, true);
        } else if (currentEvent.name.equals("Script.TargetWidth")) {
            handleScriptTargetWidth(currentEvent, true);
        } else if (currentEvent.name.equals("Script.BeginBigBlock")) {
            handleScriptBeginBigBlock(currentEvent, true);
        } else if (currentEvent.name.equals("Script.BeginBlock")) {
            handleScriptBeginBlock(currentEvent, true);
        } else if (currentEvent.name.equals("Script.ShowDiscardedTarget")) {
            handleScriptShowTarget(currentEvent, true, true);
            --skipForward;
            if (skipForward == 0) {
                break;
            }
        } else if (currentEvent.name.equals("Script.ShowTarget")) {
            handleScriptShowTarget(currentEvent, false, true);
        } else if (currentEvent.name.equals("Script.ShowTargetIndicator")) {
            handleScriptShowTargetIndicator(currentEvent, true);
        } else if (currentEvent.name.equals("Script.HideTargetIndicator")) {
            handleScriptHideTargetIndicator(currentEvent, true);
        } else {
            System.out.printf("unrecognized script event %s\n", currentEvent.name);
            System.exit(1);
        }
    }

    if (currentEvent == null) {
        // Go to the readScript function to show the end-of-trial dialog and
        // exit.
        readScript();
    } else {
        // We have a ShowDiscardedTarget event. We yield control back to
        // the user. We don't need to log anything for it, as the log
        // file ended immediately after showing a discarded target.
        activeTarget.show();
    }
}


/**
 * Advance through the script.
 */
void readScript() {
    ScriptEvent currentEvent;
    while ((currentEvent = readNextScriptEvent()) != null) {
        if (currentEvent.name.equals("Script.Start")) {
            if (handleScriptStart(currentEvent)) break;
        } else if (currentEvent.name.equals("Script.InteractionMode")) {
            if (handleScriptInteractionMode(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.TargetWidth")) {
            if (handleScriptTargetWidth(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.BeginBigBlock")) {
            if (handleScriptBeginBigBlock(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.BeginBlock")) {
            if (handleScriptBeginBlock(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.ShowDiscardedTarget")) {
            if (handleScriptShowTarget(currentEvent, true, false)) break;
        } else if (currentEvent.name.equals("Script.ShowTarget")) {
            if (handleScriptShowTarget(currentEvent, false, false)) break;
        } else if (currentEvent.name.equals("Script.ShowTargetIndicator")) {
            if (handleScriptShowTargetIndicator(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.HideTargetIndicator")) {
            if (handleScriptHideTargetIndicator(currentEvent, false)) break;
        } else {
            System.out.printf("unrecognized script event %s\n", currentEvent.name);
            System.exit(1);
        }
    }
    if (currentEvent == null) {
        activeTarget.hide();
        thankYouDialog.show();
        logEvent(new HybridTrialEndedEvent());
        trialState = TRIALSTATE_THANK_YOU;
        println("\n");
    }
}


/**
 * Initialize variables from the script. Return whether to stop consuming
 * events (always false.)
 * @param currentEvent the event to process
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptStart(ScriptEvent currentEvent) {
    multipleInteractionModes = ((Number) currentEvent.data.get("multiple_modes")).intValue() != 0;
    DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH-mm-ss");
    String time = dateFormat.format(Calendar.getInstance().getTime());
    logEvent(new HybridStartupEvent(time, CONFIG_SCRIPT, machineTrialScale));
    return false;
}


/**
 * Change the current interaction mode based on the current event. Return
 * whether to stop consuming events.
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptInteractionMode(ScriptEvent currentEvent, boolean consuming) {
    String mode = (String) currentEvent.data.get("mode");
    setInteractionMode(mode);
    if (!consuming) {
        logEvent(new HybridInteractionModeChangedEvent(mode));
        if (multipleInteractionModes) {
            trialState = TRIALSTATE_DISPLAY_INTERACTION_MODE;
            interactionModeDialog.show();
            interactionModeDialog.mode = mode;
            activeTarget.hide();
            return true;
        }
    }
    return false;
}


/**
 * Log a change in target widths. If we are showing a dialog box for each
 * different target width, display it and wait for interaction. Otherwise,
 * continue reading events. Return whether or not to stop reading
 * events.
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptTargetWidth(ScriptEvent currentEvent, boolean consuming) {
    // We don't need to do anything with this value other than log it.
    // The width is repeated in the ShowTarget/ShowDiscardedTarget
    // events.
    logEvent(new HybridTargetWidthChangedEvent(((Number) currentEvent.data.get("target_width")).intValue()));
    if (!consuming) {
        if (!multipleInteractionModes) {
            if (trialState != TRIALSTATE_BREAK_THE_TARGETS) {
                targetWidthDialog.setDisplayIntroText();
            } else {
                targetWidthDialog.setDisplayOtherText();
            }
            targetWidthDialog.show();
            activeTarget.hide();
            trialState = TRIALSTATE_DISPLAY_TARGET_WIDTH;
            return true;
        }
    }
    return false;
}


/**
 * Show a dialog for the beginning of a big block and log it. Return whether or
 * not to stop reading events (always false).
 *
 * This does nothing right now, but should eventually log an event, show a dialog
 * box and return true.
 *
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptBeginBigBlock(ScriptEvent currentEvent, boolean consuming) {
    int standingPosition = ((Number) currentEvent.data.get("standing_x")).intValue();
    logEvent(new HybridBeginBigBlockEvent(standingPosition));
    if (!consuming) {
        if (!interactionModeIsStationary()) {
            if (trialState != TRIALSTATE_BREAK_THE_TARGETS) {
                // Do nothing; just showing the interaction mode dialog is fine.
                // Continue to the next event and start showing targets.
                return false;
            } else {
                bigBlockDialog.setDisplayStandingPosition(false, 0.0);
                bigBlockDialog.setDisplayTakeABreakText(true);
            }
        } else {
            if (trialState != TRIALSTATE_BREAK_THE_TARGETS) {
                bigBlockDialog.setDisplayStandingPosition(true, standingPosition);
                bigBlockDialog.setDisplayTakeABreakText(false);
                standingPositionIndicator.setPositionWithData(currentEvent.data);
                standingPositionIndicator.show();
            } else {
                bigBlockDialog.setDisplayStandingPosition(true, standingPosition);
                bigBlockDialog.setDisplayTakeABreakText(true);
                standingPositionIndicator.setPositionWithData(currentEvent.data);
                standingPositionIndicator.show();
            }
        }
        bigBlockDialog.show();
        activeTarget.hide();
        trialState = TRIALSTATE_DISPLAY_BIG_BLOCK;
        return true;
    }
    return false;
}


/**
 * Log the beginning of a block of targets. Return whether or not to stop reading
 * events (always false).
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptBeginBlock(ScriptEvent currentEvent, boolean consuming) {
    logEvent(new HybridBeginBlockEvent());
    return false;
}


/**
 * Show a target from a script event. Return true if we should stop reading
 * script events.
 * @param currentEvent the event to process
 * @param discarded if true, the target to be shown will not be used in experimental data
 * @param consuming if true, the program will not bother showing any modal dialogs or animations
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptShowTarget(ScriptEvent currentEvent, boolean discarded, boolean consuming) {
    float previousX = 0.0;
    float previousY = 0.0;
    if (trialState == TRIALSTATE_BREAK_THE_TARGETS) {
        previousX = activeTarget.x;
        previousY = activeTarget.y;
    }
    discardTarget = discarded;
    activeTarget.setDimensionsWithData(currentEvent.data);
    if (!consuming) {
        if (trialState == TRIALSTATE_BREAK_THE_TARGETS) {
            createAnimation(new TargetMoveAnimation(previousX, previousY, activeTarget.x, activeTarget.y));
        }
        activeTarget.show();
    }
    trialState = TRIALSTATE_BREAK_THE_TARGETS;
    if (discarded) {
        logEvent(new HybridDiscardedTargetSpawnedEvent(activeTarget.x,
                    activeTarget.y,
                    activeTarget.width,
                    activeTarget.height));
    } else {
        logEvent(new HybridTargetSpawnedEvent(activeTarget.x,
                    activeTarget.y,
                    activeTarget.width,
                    activeTarget.height));
    }
    return !consuming;
}


/**
 * Show an indicator where the target will appear.
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any animations
 * @return true if the program should stop parsing events and return control to the user (always false)
 */
boolean handleScriptShowTargetIndicator(ScriptEvent currentEvent, boolean consuming) {
    int id = (int) ((Number) currentEvent.data.get("id")).intValue();
    TargetIndicator indicator = targetIndicators[id];
    float previousX = indicator.x;
    float previousY = indicator.y;
    indicator.setDimensionsWithData(currentEvent.data);
    if (!indicator.showing) {
        indicator.show();
    } else {
        createAnimation(new TargetIndicatorMoveAnimation(id, previousX, previousY, indicator.x, indicator.y));
    }
    logEvent(new HybridTargetIndicatorSpawnedEvent(id,
                indicator.x,
                indicator.y,
                indicator.width,
                indicator.height));
    return false;
}


/**
 * Hide an indicator.
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any animations
 * @return true if the program should stop parsing events and return control to the user (always false)
 */
boolean handleScriptHideTargetIndicator(ScriptEvent currentEvent, boolean consuming) {
    int id = (int) ((Number) currentEvent.data.get("id")).intValue();
    TargetIndicator indicator = targetIndicators[id];
    indicator.hide();
    logEvent(new HybridTargetIndicatorHiddenEvent(id));
    return false;
}


/**
 * Clear the screen and draw one frame.
 */
void draw() {
    frame.setLocation(0, 0);
    background(0);
    ++time;

    if (CONFIG_PLAYBACK_LOG != null) {
        displayPlayback();
        return;
    }

    updateTouchInputFilter();
    updateInteraction();
    interactionModeDialog.update();
    targetWidthDialog.update();
    bigBlockDialog.update();
    targetPracticeDialog.update();

    if (hadScreenOffsetResetThisFrame) {
        hadScreenOffsetResetThisFrame = false;
    } else {
        screenOffsetResetBuildup = 1.0;
    }

    if (forceReset) {
        registerPullReset();
        registerPullReset();
        if (Math.abs(displayOffsetX) < 0.1 && Math.abs(displayOffsetY) < 0.1) {
            forceReset = false;
        }
    }

    displayOffsetX = screenOffsetX;
    displayOffsetY = screenOffsetY;
    displayScreenBoundaries(displayOffsetX, displayOffsetY);

    if (CONFIG_SHOW_DEAD_ZONES) {
        displayInteractionDeadZones();
    }

    if (CONFIG_SHOW_DEBUG_PARTICIPANT) {
        displayParticipantDebug();
    }

    for (TargetIndicator indicator: targetIndicators) {
        indicator.display();
    }
    activeTarget.display();
    standingPositionIndicator.display();
    displayAnimations();
    displayInteraction();
    interactionModeDialog.display();
    targetWidthDialog.display();
    bigBlockDialog.display();
    targetPracticeDialog.display();
    if (trialState == TRIALSTATE_BREAK_THE_TARGETS) {
        if (CONFIG_HYPERTAP || (CONFIG_SUPERTAP && time % 10 == 0)) {
            registerClick(activeTarget.x, activeTarget.y, "HyperTap", 69, System.currentTimeMillis());
        }
    } else if (trialState == TRIALSTATE_DISPLAY_INTERACTION_MODE) {
        if (interactionModeDialog.finished || CONFIG_EXPERT_MODE && interactionModeDialog.animationTime < 0.2) {
            forceReset = true;
            interactionModeDialog.hide();
            if (CONFIG_TARGET_PRACTICE) {
                targetPracticeDialog.show();
                activeTarget.placeRandomly();
                trialState = TRIALSTATE_TARGET_PRACTICE;
            } else {
                readScript();
            }
        }
    } else if (trialState == TRIALSTATE_DISPLAY_TARGET_WIDTH) {
        if (targetWidthDialog.finished || CONFIG_EXPERT_MODE && interactionModeDialog.animationTime < 0.2) {
            forceReset = true;
            targetWidthDialog.hide();
            readScript();
        }
    } else if (trialState == TRIALSTATE_DISPLAY_BIG_BLOCK) {
        if (bigBlockDialog.finished || CONFIG_EXPERT_MODE && interactionModeDialog.animationTime < 0.2) {
            forceReset = true;
            bigBlockDialog.hide();
            standingPositionIndicator.hide();
            readScript();
        }
    } else if (trialState == TRIALSTATE_TARGET_PRACTICE) {
        if (targetPracticeDialog.finished || CONFIG_EXPERT_MODE && interactionModeDialog.animationTime < 0.2) {
            forceReset = true;
            activeTarget.hide();
            targetPracticeDialog.hide();
            readScript();
        }
    } else if (trialState == TRIALSTATE_THANK_YOU) {
        thankYouDialog.update();
        thankYouDialog.display();
        if (thankYouDialog.finished) {
            System.exit(0);
        }
    }
    if (CONFIG_SHOW_DEBUG_TOUCHES) {
        displayDebugTouchInput();
    }
    if (CONFIG_SHOW_USER_TOUCHES) {
        displayUserTouchInput();
    }
}


void filteredTouchDown(FilteredTouch touch) {
    interactionTouchDown(touch);
}


void filteredTouchUp(FilteredTouch touch) {
    interactionTouchUp(touch);
}


void filteredTouchMove(FilteredTouch touch) {
    interactionTouchMove(touch);
}


void filteredTouchSignificantMove(FilteredTouch touch) {
    interactionTouchSignificantMove(touch);
}


void filteredTouchTap(FilteredTouch touch) {
    interactionTouchTap(touch);
}


/**
 * A target that can be clicked on.
 */
class Target {
    /** X-position of the target */
    float x;
    /** Y-position of the target */
    float y;
    /** Width of the target */
    float width;
    /** Height of the target (NOT USED: We're using circular targets...) */
    float height;
    /** Whether or not this is part of target practice */
    boolean isPracticeTarget;
    /** Whether or not to show this target */
    boolean showing;
    /** When this target was spawned */
    long spawnTime;
    Target(float x, float y, float width, float height, boolean practice, long spawnTime) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.isPracticeTarget = practice;
        this.spawnTime = spawnTime;
        this.showing = false;
    }
    /**
     * Make this target visible and enable interaction.
     */
    void show() {
        this.showing = true;
        this.spawnTime = System.currentTimeMillis();
        createAnimation(new TargetSpawnAnimation(this.x, this.y, this.width, this.height));
    }
    /**
     * Make this target invisible and disable interaction.
     */
    void hide() {
        this.showing = false;
    }
    /**
     * Draw this target onscreen.
     */
    void display() {
        if (this.showing) {
            displayTarget(this.x, this.y, this.width, this.height);
        }
    }
    /**
     * Attempt to click on this target.
     * @param x the x-coordinate of the touch
     * @param y the y-coordinate of the touch
     * @return whether or not this target was touched
     */
    boolean click(float x, float y) {
        float distance = (new PVector(x - this.x, y - this.y)).mag();
        if (distance < this.width / 2) {
            createAnimation(new TargetHitAnimation(this.x, this.y, this.width, this.height));
            return true;
        } else {
            if (!this.isPracticeTarget) {
                createAnimation(new TargetMissedAnimation(this.x, this.y, this.width, this.height));
            }
            return false;
        }
    }
    /**
     * Update this target's dimensions with the data from a ShowTarget event
     * from the script.
     */
    void setDimensionsWithData(JSONObject data) {
        this.x = (int) (((Number) data.get("x")).doubleValue() * machineTrialScale);
        this.y = (int) (((Number) data.get("y")).doubleValue() * machineTrialScale);
        this.width = (int) (((Number) data.get("w")).doubleValue() * machineTrialScale);
        this.height = (int) (((Number) data.get("h")).doubleValue() * machineTrialScale);
    }
    /**
     * Put this target in a random position for target practice, avoiding placing
     * it behind the target practice dialog.
     */
    void placeRandomly() {
        float px = this.x;
        float py = this.y;
        do {
            this.width = this.height = Math.random() > 0.5 ? 94 : 188;
            this.x = (int) ((float) Math.random() * (machineScreenWidth - this.width * 2 - 32) + this.width + 16);
            this.y = (int) ((float) Math.random() * (machineScreenHeight - this.height * 2 - 32) + this.height + 16);
        } while (targetPracticeDialog.targetIsBehindDialog(this.x, this.y, this.width)
        || (this.showing && (this.x - px) * (this.x - px) + (this.y - py) * (this.y - py) < 256 * 256));
        if (this.showing) {
            createAnimation(new TargetMoveAnimation(px, py, this.x, this.y));
        }
        this.show();
    }
}


/**
 * An indicator for where the next target is going to be.
 */
class TargetIndicator {
    /** id of the indicator */
    int id;
    /** X-position of the indicator */
    float x;
    /** Y-position of the indicator */
    float y;
    /** Width of the indicator */
    float width;
    /** Height of the indicator (NOT USED: We're using circular targets...) */
    float height;
    /** Whether or not to show this indicator */
    boolean showing;
    TargetIndicator(int id, float x, float y, float width, float height) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.showing = false;
    }
    /**
     * Make this target visible and enable interaction.
     */
    void show() {
        this.showing = true;
    }
    /**
     * Make this target invisible and disable interaction.
     */
    void hide() {
        this.showing = false;
    }
    /**
     * Draw this target onscreen.
     */
    void display() {
        if (this.showing) {
            displayTargetIndicator(this.id, this.x, this.y, this.width, this.height);
        }
    }
    /**
     * Update this target's dimensions with the data from a ShowTargetIndicator event
     * from the script.
     */
    void setDimensionsWithData(JSONObject data) {
        this.x = (int) (((Number) data.get("x")).doubleValue() * machineTrialScale);
        this.y = (int) (((Number) data.get("y")).doubleValue() * machineTrialScale);
        this.width = (int) (((Number) data.get("w")).doubleValue() * machineTrialScale);
        this.height = (int) (((Number) data.get("h")).doubleValue() * machineTrialScale);
    }
}

/**
 * An indicator for where the participant should be standing.
 */
class StandingPositionIndicator {
    /** X-position of the indicator */
    float x;
    /** Whether or not to show this indicator */
    boolean showing;
    StandingPositionIndicator(float x) {
        this.x = x;
        this.showing = false;
    }
    /**
     * Make this indicator visible.
     */
    void show() {
        if (!this.showing) {
            createAnimation(new StandingPositionIndicatorSpawnAnimation(this.x));
            logEvent(new HybridStandingPositionIndicatorShownEvent(this.x));
        }
        this.showing = true;
    }
    /**
     * Make this indicator invisible.
     */
    void hide() {
        if (this.showing) {
            createAnimation(new StandingPositionIndicatorDespawnAnimation(this.x));
            logEvent(new HybridStandingPositionIndicatorHiddenEvent());
        }
        this.showing = false;
    }
    /**
     * Draw this indicator onscreen.
     */
    void display() {
        if (this.showing) {
            displayStandingPositionIndicator(this.x);
        }
    }
    /**
     * Update this indicator's dimensions with the data from a ShowTargetIndicator event
     * from the script.
     */
    void setPositionWithData(JSONObject data) {
        this.x = (int) (((Number) data.get("standing_x")).doubleValue() * machineTrialScale);
    }
}

