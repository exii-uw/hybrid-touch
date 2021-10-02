import ddf.minim.spi.*;
import ddf.minim.signals.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;
import ddf.minim.effects.*;

import java.util.*;

final String  CONFIG_SCRIPT = "../script/script.csv";
final boolean CONFIG_TARGET_PRACTICE = true; // Allow user to practice interaction technique
final boolean CONFIG_SHOW_DEBUG_TOUCHES = false; // Display the position of touches and filters
final boolean CONFIG_SHOW_USER_TOUCHES = true; // Display the position of filtered touches only
final boolean CONFIG_SHOW_DEAD_ZONES = true; // Display the touch dead zones
final boolean CONFIG_HYPERTAP = false; // Tap the targets for me, dammit, I'm a busy man
final boolean CONFIG_SUPERTAP = false; // Tap the targets for me, but gently
final boolean CONFIG_EXPERT_MODE = false; // I know how to do all this stuff. Skip dialog boxes.
final boolean CONFIG_COOPERATIVE_MODE = false; // The game is laid out to encourage cooperative over competitive bhvr.
final boolean CONFIG_SEPARATE_EARTH_HEALTH = false; // If true, then in competitive mode, earth has separate healths.
final boolean CONFIG_MOVABLE_WORKSPACES = true; // If false, use half-screen workspaces
final String  CONFIG_PARTICIPANTS[] = {"Praline", "Stiffany"}; // Participant names
// Set this to a non-null value, and the screen of the current machine will be
// scaled to accommodate the screen of the named machine.
final String  CONFIG_APPLY_VIRTUAL_SCALE = "hci-bigscreen";
// Set this to a valid non-null path, and the script will fast-forward to the next ShowDiscardedTarget
// event and resume logging to this file.
final String  CONFIG_RESUME_LOG = null;
// Set this to a valid non-null path, and the script will, instead of running a trial, play back the
// results of the given trial.
final String  CONFIG_PLAYBACK_LOG = null;
final float   CONFIG_PLAYBACK_SPEED = 2.0; // 2.0 is double speed, etc.
// Set this to a nonzero value to start the playback at a specific timestamp in the log.
final long    CONFIG_PLAYBACK_START_TIMESTAMP = 0;


final long    SYNC_TIME = 60;
long          currentSyncTime = SYNC_TIME;


boolean fastForward = false;


final int EARTH_MAX_HEALTH = 50;
final int EARTH_DAMAGE_TAKEN_FROM_ENEMY = 1;
float earthRadius;


long time = 0;


class TrialState { TrialState() { } }
final TrialState TRIALSTATE_BEGIN = new TrialState();
final TrialState TRIALSTATE_DISPLAY_BIG_BLOCK = new TrialState();
final TrialState TRIALSTATE_DISPLAY_SYNC = new TrialState();
final TrialState TRIALSTATE_DISPLAY_RESUME_SYNC = new TrialState();
final TrialState TRIALSTATE_TARGET_PRACTICE = new TrialState();
final TrialState TRIALSTATE_BREAK_THE_TARGETS = new TrialState();
final TrialState TRIALSTATE_THANK_YOU = new TrialState();
TrialState trialState = TRIALSTATE_BEGIN;


BeginBlockDialog beginBlockDialog;
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


void keyPressed() {
    if (keyCode == 32) {
        fastForward = true;
    }
}


void keyReleased() {
    if (keyCode == 32) {
        fastForward = false;
    }
}


/**
 * Prepare the window.
 */
void setup() {
    initializeMachineSpecificParameters();
    smooth(0);
    size(trueMachineScreenWidth, trueMachineScreenHeight, SMT.RENDERER);
    SMT.init(this, TouchSource.AUTOMATIC);
    SMT.setTouchDraw(TouchDraw.NONE);
    colorMode(RGB, 255);
    background(0);
    strokeWeight(STROKE_WEIGHT);

    earthRadius = 256 * machineTrialScale;
    initializeSound();
    initializeWorkspaces();
    initializeWeapons();
    initializeDialogs();

    beginBlockDialog = new BeginBlockDialog();
    thankYouDialog = new ThankYouDialog();
    if (CONFIG_PLAYBACK_LOG != null) {
        // startPlayback(CONFIG_PLAYBACK_LOG, CONFIG_PLAYBACK_SPEED, CONFIG_PLAYBACK_START_TIMESTAMP);
    } else {
        loadScript(CONFIG_SCRIPT);
        if (CONFIG_RESUME_LOG != null) {
            // Start consuming events until we come up to the last
            // BeginWave event that was logged. Begin that wave,
            // display a sync, and then continue when that sync is
            // complete.
            disableLogging();
            consumeScript();
            enableLogging();
            initializeLogger(CONFIG_RESUME_LOG);
            logEvent(new HybridTrialResumedEvent());
            trialState = TRIALSTATE_DISPLAY_RESUME_SYNC;
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
 * Acknowledge that a participant received credit for destroying an enemy.
 *
 * @param participant the participant that received credit
 * @param weapon      the name of the weapon used
 * @param wx          the x-coordinate of the weapon used to defeat the enemy
 * @param wy          the y-coordinate of the weapon used to defeat the enemy
 * @param eId         the identifier of the defeated enemy
 * @param ex          the x-coordinate of enemy that was defeated
 * @param ey          the y-coordinate of enemy that was defeated
 * @param touch       the touch that was used to defeat the enemy, or null if not relevant
 * @param source      additional details about how the enemy was defeated
 */
void creditParticipant(String participant,
                       String weapon, float wx, float wy,
                       int eId, float ex, float ey,
                       FilteredTouch touch, String source) {
    int newScore = workspaceIncrementParticipantScore(participant);
    logEvent(new HybridParticipantCreditedEvent(participant, newScore, weapon, wx, wy, eId, ex, ey,
                touch == null ? 0 : touch.id, source));
}


/**
 * Called when a wave of enemies is completed, to resume reading the script and
 * prepare the next wave (or move on to a new block/condition/etc.)
 */
void registerWaveCompleted() {
    readScript();
}


/**
 * Called when an enemy collides with earth from a given angle.
 */
void registerCollisionWithEarth(float dx, float dy) {
    float currentAngle = -PI / 2;
    float angleDelta = TWO_PI / getWorkspaces().size();
    float angleOfAttack = (float) Math.atan2(dy, dx);
    while (angleOfAttack > 3 * PI / 2) {
        angleOfAttack -= TWO_PI;
    }
    while (angleOfAttack < -PI / 2) {
        angleOfAttack += TWO_PI;
    }
    for (Workspace workspace: getWorkspaces()) {
        if (currentAngle <= angleOfAttack && angleOfAttack < currentAngle + angleDelta) {
            workspace.damageTaken += EARTH_DAMAGE_TAKEN_FROM_ENEMY;
            logEvent(new HybridDamageTakenChangedEvent(workspace.participantIdentifier,
                                                       workspace.damageTaken,
                                                       EARTH_MAX_HEALTH));
        }
        currentAngle += angleDelta;
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
        if (line.contains("Trial.BeginWave")) {
            ++skipForward;
        }
        if (line.contains("Trial.ParticipantCredited") ||
            line.contains("Trial.DamageTakenChanged")) {
            int comma = line.indexOf(',');
            String eventNameDataString = line.substring(comma + 1);
            int nextComma = eventNameDataString.indexOf(',');
            String eventDataString = eventNameDataString.substring(nextComma + 1);
            JsonReader reader = Json.createReader(new StringReader(eventDataString));
            JsonObject eventData = reader.readObject();
            reader.close();
            if (line.contains("Trial.ParticipantCredited")) {
                String name = (String) eventData.getJsonString("participant").getString();
                int score = (int) eventData.getJsonNumber("newScore").intValue();
                for (Workspace workspace: getWorkspaces()) {
                    if (workspace.participantIdentifier.equals(name)) {
                        workspace.participantScore = score;
                    }
                }
            }
            if (line.contains("Trial.DamageTakenChanged")) {
                String name = (String) eventData.getJsonString("participant").getString();
                int damage = (int) eventData.getJsonNumber("damage").intValue();
                for (Workspace workspace: getWorkspaces()) {
                    if (workspace.participantIdentifier.equals(name)) {
                        workspace.damageTaken = damage;
                    }
                }
            }
        }
        if (line.contains("Trial.Ended")) {
            println("ERROR: Attempted to resume an experiment that completed normally.");
            System.exit(2);
        }
    }

    ScriptEvent currentEvent;
    while ((currentEvent = readNextScriptEvent()) != null) {
        if (currentEvent.name.equals("Script.Start")) {
            handleScriptStart(currentEvent);
        } else if (currentEvent.name.equals("Script.BeginBlock")) {
            handleScriptBeginBlock(currentEvent, true);
        } else if (currentEvent.name.equals("Script.BeginWave")) {
            handleScriptBeginWave(currentEvent, true);
            --skipForward;
            if (skipForward == 0) {
                break;
            }
        } else if (currentEvent.name.equals("Script.EndWave")) {
            handleScriptEndWave(currentEvent, true);
        } else if (currentEvent.name.equals("Script.EndBlock")) {
            handleScriptEndBlock(currentEvent, true);
        } else if (currentEvent.name.equals("Script.SpawnEnemy")) {
            handleScriptSpawnEnemy(currentEvent, true);
        } else if (currentEvent.name.equals("Script.End")) {
            handleScriptEnd(currentEvent, false);
        } else {
            System.out.printf("unrecognized script event %s\n", currentEvent.name);
            System.exit(1);
        }
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
        } else if (currentEvent.name.equals("Script.BeginBlock")) {
            if (handleScriptBeginBlock(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.BeginWave")) {
            if (handleScriptBeginWave(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.EndWave")) {
            if (handleScriptEndWave(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.EndBlock")) {
            if (handleScriptEndBlock(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.SpawnEnemy")) {
            if (handleScriptSpawnEnemy(currentEvent, false)) break;
        } else if (currentEvent.name.equals("Script.End")) {
            if (handleScriptEnd(currentEvent, false)) break;
        } else {
            System.out.printf("unrecognized script event %s\n", currentEvent.name);
            System.exit(1);
        }
    }

    if (currentEvent == null) {
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
    // multipleInteractionModes = ((Number) currentEvent.data.get("multiple_modes")).intValue() != 0;
    DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH-mm-ss");
    String time = dateFormat.format(Calendar.getInstance().getTime());
    JsonObject arguments = currentEvent.data.getJsonObject("arguments");
    configureEnemies(arguments);
    logEvent(new HybridStartupEvent(time,
                CONFIG_SCRIPT,
                arguments,
                machineTrialScale,
                CONFIG_COOPERATIVE_MODE,
                CONFIG_SEPARATE_EARTH_HEALTH,
                CONFIG_MOVABLE_WORKSPACES));
    logWorkspaces();
    return false;
}


/**
 *
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptBeginBlock(ScriptEvent currentEvent, boolean consuming) {
    if (!consuming) {
        // Only reset the earth's health if we're not resuming from the log.
        // The log will have already set the earth's health to the correct
        // value.
        for (Workspace workspace: getWorkspaces()) {
            workspace.damageTaken = 0;
            logEvent(new HybridDamageTakenChangedEvent(workspace.participantIdentifier,
                                                       0,
                                                       EARTH_MAX_HEALTH));
        }
    }
    logEvent(new HybridBeginBlockEvent());
    if (!consuming) {
        if (trialState != TRIALSTATE_BREAK_THE_TARGETS) {
            beginBlockDialog.setDisplayTakeABreakText(false);
        } else {
            beginBlockDialog.setDisplayTakeABreakText(true);
        }
        beginBlockDialog.show();
        trialState = TRIALSTATE_DISPLAY_BIG_BLOCK;
        return true;
    }
    return false;
}


/**
 *
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptEndBlock(ScriptEvent currentEvent, boolean consuming) {
    return false;
}


/**
 * Begin a new wave of enemy spawns.
 *
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptBeginWave(ScriptEvent currentEvent, boolean consuming) {
    beginNewWave();
    logEvent(new HybridBeginWaveEvent(getCurrentWaveNumber()));
    currentSyncTime = SYNC_TIME;
    trialState = TRIALSTATE_DISPLAY_SYNC;
    return !consuming;
}


/**
 * Finish reading in a single wave of enemies and return control to the user, allowing
 * them to begin selecting enemies.
 *
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptEndWave(ScriptEvent currentEvent, boolean consuming) {
    trialState = TRIALSTATE_BREAK_THE_TARGETS;
    return true;
}


/**
 * Add a new enemy to the list of enemies that will be spawned during this wave.
 *
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptSpawnEnemy(ScriptEvent currentEvent, boolean consuming) {
    String type = currentEvent.data.getString("type");
    float speed = (float) currentEvent.data.getJsonNumber("speed").doubleValue();
    float angle = (float) currentEvent.data.getJsonNumber("angle").doubleValue();
    float spawnTime = (float) currentEvent.data.getJsonNumber("spawnTime").doubleValue();
    addEnemy(type, angle, speed, spawnTime);
    return false;
}


/**
 * Finish the script.
 *
 * @param currentEvent the event to process
 * @param consuming if true, the program will not bother showing any modal dialogs
 * @return true if the program should stop parsing events and return control to the user
 */
boolean handleScriptEnd(ScriptEvent currentEvent, boolean consuming) {
    logEvent(new HybridTrialEndedEvent());
    return false;
}


/**
 * Clear the screen and draw one frame.
 */
void draw() {
    frame.setLocation(0, 0);
    background(0);
    scale((float) Math.min(1.0 / machineInputScalingX, 1.0 / machineInputScalingY));
    ++time;

    if (CONFIG_PLAYBACK_LOG != null) {
        // displayPlayback();
        return;
    }

    updateSound();

    int iterations = (fastForward ? 16 : 1) * (CONFIG_HYPERTAP ? 32 : 1);
    for (int i = 0; i < iterations; ++i) {
        updateTouchInputFilter();
        updateWeapons();

        if (trialState == TRIALSTATE_BREAK_THE_TARGETS) {
            updateEnemies(machineScreenWidth / 2.0, machineScreenHeight / 2.0, earthRadius);
            if (CONFIG_HYPERTAP) {
                killArbitraryEnemy();
            }
        }

        for (Workspace workspace: getWorkspaces()) {
            workspace.update();
        }
    }

    beginBlockDialog.update();

    if (trialState == TRIALSTATE_DISPLAY_SYNC) {
        --currentSyncTime;
        if (currentSyncTime <= 0) {
            readScript();
        }
        displaySync(getCurrentWaveNumber());
        return;
    }

    if (trialState == TRIALSTATE_DISPLAY_RESUME_SYNC) {
        --currentSyncTime;
        if (currentSyncTime <= 0) {
            readScript();
        }
        displayResume();
        return;
    }

    if (CONFIG_COOPERATIVE_MODE || !CONFIG_SEPARATE_EARTH_HEALTH) {
        int totalHealth = EARTH_MAX_HEALTH * getWorkspaces().size();
        int currentHealth = totalHealth;
        for (Workspace workspace: getWorkspaces()) {
            currentHealth -= workspace.damageTaken;
        }
        if (currentHealth < 0) {
            currentHealth = 0;
        }
        displayEarth(machineScreenWidth / 2.0, machineScreenHeight / 2.0, earthRadius,
                (float) currentHealth / (float) totalHealth,
                (float) time / 1000.0, -PI / 2.0, 3.0 * PI / 2.0);
    } else {
        float currentAngle = -PI / 2.0;
        float angleDelta = TWO_PI / (float) getWorkspaces().size();
        for (Workspace workspace: getWorkspaces()) {
            int currentHealth = EARTH_MAX_HEALTH - workspace.damageTaken;
            if (currentHealth < 0) {
                currentHealth = 0;
            }
            displayEarth(machineScreenWidth / 2.0, machineScreenHeight / 2.0, earthRadius,
                    (float) currentHealth / (float) EARTH_MAX_HEALTH,
                    (float) time / 1000.0, currentAngle, currentAngle + angleDelta);
            currentAngle += angleDelta;
        }
    }

    displayWaveCount(getCurrentWaveNumber());

    for (Workspace workspace: getWorkspaces()) {
        workspace.displayWorkspace();
    }

    if (CONFIG_COOPERATIVE_MODE) {
        int score = 0;
        for (Workspace workspace: getWorkspaces()) {
            score += workspace.participantScore - workspace.damageTaken;
        }
        displaySummedScore(score);
    }

    for (Workspace workspace: getWorkspaces()) {
        workspace.displayInteraction();
    }

    displayEnemies();
    displayWeapons();
    displayAnimations();

    beginBlockDialog.display();

    if (trialState == TRIALSTATE_BREAK_THE_TARGETS) {
    } else if (trialState == TRIALSTATE_DISPLAY_BIG_BLOCK) {
        if (beginBlockDialog.finished || (CONFIG_EXPERT_MODE && beginBlockDialog.animationTime < 0.2)) {
            beginBlockDialog.hide();
            readScript();
        }
    } else if (trialState == TRIALSTATE_TARGET_PRACTICE) {
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
    for (Workspace workspace: getWorkspaces()) {
        workspace.touchDown(touch);
    }
    for (Weapon weapon: weapons) {
        weapon.touchDown(touch);
    }
}


void filteredTouchUp(FilteredTouch touch) {
    for (Workspace workspace: getWorkspaces()) {
        workspace.touchUp(touch);
    }
    for (Weapon weapon: weapons) {
        weapon.touchUp(touch);
    }
}


void filteredTouchMove(FilteredTouch touch) {
    for (Workspace workspace: getWorkspaces()) {
        workspace.touchMove(touch);
    }
    for (Weapon weapon: weapons) {
        weapon.touchMove(touch);
    }
}


void filteredTouchSignificantMove(FilteredTouch touch) {
    for (Workspace workspace: getWorkspaces()) {
        workspace.touchSignificantMove(touch);
    }
    for (Weapon weapon: weapons) {
        weapon.touchSignificantMove(touch);
    }
}


void filteredTouchTap(FilteredTouch touch) {
    for (Workspace workspace: getWorkspaces()) {
        workspace.touchTap(touch);
    }
    for (Weapon weapon: weapons) {
        weapon.touchTap(touch);
    }
}

