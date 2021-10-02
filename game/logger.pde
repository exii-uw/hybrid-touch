
import java.io.FileWriter;
import java.io.PrintWriter;
import java.util.Calendar;
import java.text.DateFormat;
import java.text.SimpleDateFormat;


private EventWriter log = null;
private boolean loggingEnabled = false;


/**
 * Start up the logger.
 * This function ensures that all logging calls are printed
 * to a file of the format "yyyy-MM-dd HH-mm-ss.csv".
 */
void initializeLogger(String resumeLog) {
    String filename;
    if (resumeLog == null) {
        DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH-mm-ss");
        String time = dateFormat.format(Calendar.getInstance().getTime());
        filename = String.format("log/%s.csv", time);
    } else {
        filename = resumeLog;
    }
    log = new EventWriter(filename);
    System.out.printf("Logging to %s\n", filename);
    loggingEnabled = true;
}


/**
 * Cause any future logged events to be written to the currently open logfile.
 */
void enableLogging() {
    loggingEnabled = true;
}


/**
 * Cause any future logged events not to be written to the currently open logfile.
 */
void disableLogging() {
    loggingEnabled = false;
}


/**
 * Record an event happening right now.
 * @param event the event to log
 */
void logEvent(HybridTouchEvent event) {
    if (loggingEnabled) {
        log.logEvent(System.currentTimeMillis(), event);
    }
}


/**
 * An interface for anything which can be recorded in the logfile.
 */
interface HybridTouchEvent {
    /**
     * A unique identifier that can be used to identify the class of this event.
     * @return the unique identifier
     */
    String eventType();
    /**
     * A JSON object listing all the extra parameters specific to this event.
     * @return a valid JSON string
     */
    String details();
    /**
     * Return true if the logger should be flushed immediately after this
     * event. By selecting whether or not to flush the logger manually, we can
     * make it easier to resume logging where we left off. If this is false,
     * the buffer will not be flushed until it receives a flush event; this
     * is why it's important to send the HybridTrialEndedEvent.
     * @return whether to flush
     */
    boolean isFlushEvent();
}


/**
 * Logged when the trial starts.
 */
class HybridStartupEvent implements HybridTouchEvent {
    /** The current time. */
    String time;
    /** The filename of the script used to run this trial. */
    String script;
    /** The arguments that were used to generate the script. */
    JsonObject scriptArguments;
    /** The scale at which this trial was run. */
    float scale;
    /** Whether the trial was done in cooperative mode or competitive mode. */
    boolean cooperative;
    /** If run in competitive mode, whether the earth has separate healths for each participant. */
    boolean separateEarthHealth;
    /** Whether or not the participants are able to move their workspaces. */
    boolean movableWorkspaces;
    HybridStartupEvent(String time,
                       String script,
                       JsonObject scriptArguments,
                       float scale,
                       boolean cooperative,
                       boolean separateEarthHealth,
                       boolean movableWorkspaces) {
        this.time = time;
        this.script = script;
        this.scriptArguments = scriptArguments;
        this.scale = scale;
        this.cooperative = cooperative;
        this.separateEarthHealth = separateEarthHealth;
        this.movableWorkspaces = movableWorkspaces;
    }
    String eventType() {
        return "System.Startup";
    }
    String details() {
        return String.format("{" +
                             "\"time\":\"%s\"," +
                             "\"script\":\"%s\"," +
                             "\"script_arguments\":%s," +
                             "\"scale\":%f," +
                             "\"cooperative\":%d," +
                             "\"separateEarthHealth\":%d," +
                             "\"movableWorkspaces\":%d" +
                             "}",
                             this.time,
                             this.script,
                             this.scriptArguments.toString(),
                             this.scale,
                             this.cooperative ? 1 : 0,
                             this.separateEarthHealth ? 1 : 0,
                             this.movableWorkspaces ? 1 : 0);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records any physical touch on the screen, before any filtering occurs.
 */
class HybridRawTouchDownEvent implements HybridTouchEvent {
    /** The unique identifier assigned to the touch by the input driver. */
    int id;
    /** The x coordinate of where the touch occurred. */
    float x;
    /** The y coordinate of where the touch occurred. */
    float y;
    HybridRawTouchDownEvent(int id, float x, float y) {
        this.id = id;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Input.RawTouchDown";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f}", this.id, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records any physical touch lifted on the screen, before any filtering occurs.
 */
class HybridRawTouchUpEvent implements HybridTouchEvent {
    /** The unique identifier assigned to the touch by the input driver. */
    int id;
    /** The x coordinate of where the touch occurred. */
    float x;
    /** The y coordinate of where the touch occurred. */
    float y;
    HybridRawTouchUpEvent(int id, float x, float y) {
        this.id = id;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Input.RawTouchUp";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f}", this.id, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records any physical touch moved on the screen, before any filtering occurs.
 */
class HybridRawTouchMoveEvent implements HybridTouchEvent {
    /** The unique identifier assigned to the touch by the input driver. */
    int id;
    /** The x coordinate of where the touch occurred. */
    float x;
    /** The y coordinate of where the touch occurred. */
    float y;
    HybridRawTouchMoveEvent(int id, float x, float y) {
        this.id = id;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Input.RawTouchMove";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f}", this.id, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records any physical touch on the screen.
 */
class HybridTouchDownEvent implements HybridTouchEvent {
    /** The unique identifier assigned to the touch by the input driver. */
    int id;
    /** The x coordinate of where the touch occurred. */
    float x;
    /** The y coordinate of where the touch occurred. */
    float y;
    HybridTouchDownEvent(int id, float x, float y) {
        this.id = id;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Input.TouchDown";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f}", this.id, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records any physical touch lifted on the screen.
 */
class HybridTouchUpEvent implements HybridTouchEvent {
    /** The unique identifier assigned to the touch by the input driver. */
    int id;
    /** The x coordinate of where the touch occurred. */
    float x;
    /** The y coordinate of where the touch occurred. */
    float y;
    HybridTouchUpEvent(int id, float x, float y) {
        this.id = id;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Input.TouchUp";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f}", this.id, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records any physical touch moved on the screen.
 */
class HybridTouchMoveEvent implements HybridTouchEvent {
    /** The unique identifier assigned to the touch by the input driver. */
    int id;
    /** The x coordinate of where the touch occurred. */
    float x;
    /** The y coordinate of where the touch occurred. */
    float y;
    HybridTouchMoveEvent(int id, float x, float y) {
        this.id = id;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Input.TouchMove";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f}", this.id, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a series of touches spawns a cursor.
 */
class HybridCursorSpawnedEvent implements HybridTouchEvent {
    /** The participant that created the cursor.  */
    String participant;
    /**
     * The unique identifier assigned to the touch that spawned the cursor,
     * assigned by the input driver.
     */
    int id;
    /** The number of fingers total that were held down to spawn a cursor. */
    int count;
    /** The x coordinate where the cursor was spawned. */
    float x;
    /** The y coordinate where the cursor was spawned. */
    float y;
    HybridCursorSpawnedEvent(String participant, int id, int count, float x, float y) {
        this.participant = participant;
        this.id = id;
        this.count = count;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Hybrid.CursorSpawned";
    }
    String details() {
        return String.format("{" +
                "\"participant\":\"%s\"," +
                "\"id\":%d," +
                "\"count\":%d," +
                "\"x\":%f," +
                "\"y\":%f" +
                "}", this.participant, this.id, this.count, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when the spawned cursor is moved.
 */
class HybridCursorMovedEvent implements HybridTouchEvent {
    /** The participant that created the cursor.  */
    String participant;
    /** The x coordinate where the cursor was moved. */
    float x;
    /** The y coordinate where the cursor was moved. */
    float y;
    HybridCursorMovedEvent(String participant, float x, float y) {
        this.participant = participant;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Hybrid.CursorMoved";
    }
    String details() {
        return String.format("{" +
                "\"participant\":\"%s\"," +
                "\"x\":%f," +
                "\"y\":%f" +
                "}", this.participant, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a cursor disappears.
 */
class HybridCursorDespawnedEvent implements HybridTouchEvent {
    /** The participant that created the cursor.  */
    String participant;
    HybridCursorDespawnedEvent(String participant) {
        this.participant = participant;
    }
    String eventType() {
        return "Hybrid.CursorDespawned";
    }
    String details() {
        return String.format("{\"participant\":\"%s\"}", this.participant);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a finger has been "killed", i.e. can no longer be used to
 * move the cursor or trigger touch-tap events.
 */
class HybridFingerKilledEvent implements HybridTouchEvent {
    /** The unique identifier of the finger that was killed. */
    int id;
    HybridFingerKilledEvent(int id) {
        this.id = id;
    }
    String eventType() {
        return "Hybrid.FingerKilled";
    }
    String details() {
        return String.format("{\"id\":%d}", this.id);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a series of touches causes a dead zone to be created.
 */
class HybridDeadZoneSpawnedEvent implements HybridTouchEvent {
    /** The unique identifier of the dead zone. */
    int id;
    /** The x coordinate where the dead zone was spawned. */
    float x;
    /** The y coordinate where the dead zone was spawned. */
    float y;
    /** The size of the dead zone when it was spawned. */
    float radius;
    HybridDeadZoneSpawnedEvent(int id, float x, float y, float radius) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.radius = radius;
    }
    String eventType() {
        return "Hybrid.DeadZoneSpawned";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f,\"radius\":%f}", this.id, this.x, this.y, this.radius);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a dead zone changes position or size.
 */
class HybridDeadZoneChangedEvent implements HybridTouchEvent {
    /** The unique identifier of the dead zone. */
    int id;
    /** The x coordinate where the dead zone moved. */
    float x;
    /** The y coordinate where the dead zone moved. */
    float y;
    /** The size of the dead zone. */
    float radius;
    HybridDeadZoneChangedEvent(int id, float x, float y, float radius) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.radius = radius;
    }
    String eventType() {
        return "Hybrid.DeadZoneChanged";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f,\"radius\":%f}", this.id, this.x, this.y, this.radius);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a dead zone is killed. The dead zone remains, fading,
 * until it is despawned.
 */
class HybridDeadZoneKilledEvent implements HybridTouchEvent {
    /** The unique identifier of the dead zone. */
    int id;
    HybridDeadZoneKilledEvent(int id) {
        this.id = id;
    }
    String eventType() {
        return "Hybrid.DeadZoneKilled";
    }
    String details() {
        return String.format("{\"id\":%d}", this.id);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a dead zone is despawned.
 */
class HybridDeadZoneDespawnedEvent implements HybridTouchEvent {
    /** The unique identifier of the dead zone. */
    int id;
    HybridDeadZoneDespawnedEvent(int id) {
        this.id = id;
    }
    String eventType() {
        return "Hybrid.DeadZoneDespawned";
    }
    String details() {
        return String.format("{\"id\":%d}", this.id);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a weapon's state changes.
 */
class HybridWeaponChanged implements HybridTouchEvent {
    /** The weapon in question. */
    String weapon;
    /** The participant that is using the weapon, if any. */
    String participant;
    /** The finger that is holding the weapon, if any. */
    int id;
    /** The state of the weapon after the state change. */
    String state;
    HybridWeaponChanged(String weapon, String participant, int id, String state) {
        this.weapon = weapon;
        this.participant = participant;
        this.id = id;
        this.state = state;
    }
    String eventType() {
        return "Trial.WeaponChanged";
    }
    String details() {
        return String.format("{\"weapon\":\"%s\",\"participant\":\"%s\",\"id\":%d,\"state\":\"%s\"}",
                this.weapon, this.participant, this.id, this.state);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a weapon moves.
 */
class HybridWeaponMoved implements HybridTouchEvent {
    /** The weapon in question. */
    String weapon;
    /** The new x position of the weapon. */
    float x;
    /** The new y position of the weapon. */
    float y;
    HybridWeaponMoved(String weapon, float x, float y) {
        this.weapon = weapon;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Trial.WeaponMoved";
    }
    String details() {
        return String.format("{\"weapon\":\"%s\",\"x\":%f,\"y\":%f}", this.weapon, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when an enemy is spawned.
 */
class HybridEnemySpawnedEvent implements HybridTouchEvent {
    /** A unique identifier for the enemy. */
    int id;
    /** The x coordinate of the centre point of the enemy. */
    float x;
    /** The y coordinate of the centre point of the enemy. */
    float y;
    /** The radius of the enemy. */
    float r;
    /** The enemy type. */
    String type;
    HybridEnemySpawnedEvent(int id, float x, float y, float r, String type) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.r = r;
        this.type = type;
    }
    String eventType() {
        return "Trial.EnemySpawned";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f,\"r\":%f,\"type\":\"%s\"}",
                this.id, this.x, this.y, this.r, this.type);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a block of enemies begins.
 */
class HybridBeginBlockEvent implements HybridTouchEvent {
    HybridBeginBlockEvent() { }
    String eventType() {
        return "Trial.BeginBlock";
    }
    String details() {
        return "{}";
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a wave of enemies begins.
 */
class HybridBeginWaveEvent implements HybridTouchEvent {
    /** The current wave. */
    int waveNumber;
    HybridBeginWaveEvent(int waveNumber) {
        this.waveNumber = waveNumber;
    }
    String eventType() {
        return "Trial.BeginWave";
    }
    String details() {
        return String.format("{\"waveNumber\":%d}",
                this.waveNumber);
    }
    boolean isFlushEvent() { return true; }
}


/**
 * Records when an enemy is moved.
 */
class HybridEnemyMovedEvent implements HybridTouchEvent {
    /** A unique identifier for the enemy. */
    int id;
    /** The x coordinate of the centre point of the enemy. */
    float x;
    /** The y coordinate of the centre point of the enemy. */
    float y;
    HybridEnemyMovedEvent(int id, float x, float y) {
        this.id = id;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Trial.EnemyMoved";
    }
    String details() {
        return String.format("{\"id\":%d,\"x\":%f,\"y\":%f}", this.id, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a enemy has been hit.
 */
class HybridEnemyHitEvent implements HybridTouchEvent {
    /** The participant that hit the enemy. */
    String participant;
    /** A string describing how the enemy was hit, whether by touch or
     * cursor. */
    String source;
    /**
     * The unique identifier assigned to the touch by the input driver, if
     * this event was generated by a finger touch. Otherwise, an undefined
     * value.
     */
    int cid;
    /** The x coordinate where the click occured that hit the enemy. */
    float cx;
    /** The y coordinate where the click occured that hit the enemy. */
    float cy;
    /** A unique identifier for the enemy. */
    int id;
    /** The x coordinate of the centre point of the enemy. */
    float x;
    /** The y coordinate of the centre point of the enemy. */
    float y;
    /** The radius of the enemy that was hit. */
    float r;
    /** The enemy type. */
    String type;
    HybridEnemyHitEvent(
            String participant,
            String source,
            int cid,
            float cx,
            float cy,
            int id,
            float x,
            float y,
            float r,
            String type) {
        this.participant = participant;
        this.source = source;
        this.cid = cid;
        this.cx = cx;
        this.cy = cy;
        this.id = id;
        this.x = x;
        this.y = y;
        this.r = r;
        this.type = type;
    }
    String eventType() {
        return "Trial.EnemyHit";
    }
    String details() {
        return String.format("{" +
                "\"participant\":\"%s\"," +
                "\"source\":\"%s\"," +
                "\"cid\":%d," +
                "\"cx\":%f," +
                "\"cy\":%f," +
                "\"id\":%d," +
                "\"x\":%f," +
                "\"y\":%f," +
                "\"r\":%f," +
                "\"type\":\"%s\"" +
                "}",
            this.participant,
            this.source,
            this.cid,
            this.cx,
            this.cy,
            this.id,
            this.x,
            this.y,
            this.r,
            this.type);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a enemy collided with earth.
 */
class HybridEnemyCollideEvent implements HybridTouchEvent {
    /** A unique identifier for the enemy. */
    int id;
    HybridEnemyCollideEvent(int id) {
        this.id = id;
    }
    String eventType() {
        return "Trial.EnemyCollide";
    }
    String details() {
        return String.format("{\"id\":%d}", this.id);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a enemy despawned off the edge of the screen.
 */
class HybridEnemyDespawnedEvent implements HybridTouchEvent {
    /** A unique identifier for the enemy. */
    int id;
    HybridEnemyDespawnedEvent(int id) {
        this.id = id;
    }
    String eventType() {
        return "Trial.EnemyDespawned";
    }
    String details() {
        return String.format("{\"id\":%d}", this.id);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when an interaction occurred that did not eliminate any enemies.
 */
class HybridEnemyMissedEvent implements HybridTouchEvent {
    /** The participant that hit the enemy. */
    String participant;
    /** A string describing how the enemy was (not) hit, whether by touch or
     * cursor. */
    String source;
    /**
     * The unique identifier assigned to the touch by the input driver, if
     * this event was generated by a finger touch. Otherwise, an undefined
     * value.
     */
    int cid;
    /** The x coordinate where the weapon was. */
    float cx;
    /** The y coordinate where the weapon was. */
    float cy;
    /**
     * The enemy type that the participant's active tool is intended to
     * destroy, or "Enemy.None" if no tool is active.
     */
    String type;
    HybridEnemyMissedEvent (
            String participant,
            String source,
            int cid,
            float cx,
            float cy,
            String type) {
        this.participant = participant;
        this.source = source;
        this.cid = cid;
        this.cx = cx;
        this.cy = cy;
        this.type = type;
    }
    String eventType() {
        return "Trial.EnemyMissed";
    }
    String details() {
        return String.format("{" +
                "\"participant\":\"%s\"," +
                "\"source\":\"%s\"," +
                "\"cid\":%d," +
                "\"cx\":%f," +
                "\"cy\":%f," +
                "\"type\":\"%s\"" +
                "}",
            this.participant,
            this.source,
            this.cid,
            this.cx,
            this.cy,
            this.type);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records the amount of damage a specific participant has taken at a given
 * point in time, caused by enemies colliding with their portion of the
 * earth's surface.
 */
class HybridDamageTakenChangedEvent implements HybridTouchEvent {
    /** The participant who received the damage. */
    String participant;
    /** The total damage taken after the change. */
    int damage;
    /** The maximum displayed damage. */
    int maxHealth;
    HybridDamageTakenChangedEvent(String participant, int damage, int maxHealth) {
        this.participant = participant;
        this.damage = damage;
        this.maxHealth = maxHealth;
    }
    String eventType() {
        return "Trial.DamageTakenChanged";
    }
    String details() {
        return String.format("{\"participant\":\"%s\",\"damage\":%d,\"maxHealth\":%d}",
                this.participant, this.damage, this.maxHealth);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a participant recieves score credit for an action.
 */
class HybridParticipantCreditedEvent implements HybridTouchEvent {
    /** The participant whose score changed. */
    String participant;
    /** The score of the participant after the change. */
    int newScore;
    /** The name of the weapon used to acquire points, if relevant. */
    String weapon;
    /** The x coordinate of the weapon used, if relevant. */
    float cx;
    /** The y coordinate of the weapon used, if relevant. */
    float cy;
    /** The id of the enemy killed, if relevant. */
    int id;
    /** The x coordinate of the enemy killed, if relevant. */
    float x;
    /** The y coordinate of the enemy killed, if relevant. */
    float y;
    /** The touch id provided by the driver for the weapon being used to score
     * points, if relevant. */
    int cid;
    /** Additional information about the source of the points. */
    String source;
    HybridParticipantCreditedEvent(String participant,
            int newScore,
            String weapon, float cx, float cy,
            int id, float x, float y,
            int cid, String source) {
        this.participant = participant;
        this.newScore = newScore;
        this.weapon = weapon;
        this.cx = cx;
        this.cy = cy;
        this.id = id;
        this.x = x;
        this.y = y;
        this.cid = cid;
        this.source = source;
    }
    String eventType() {
        return "Trial.ParticipantCredited";
    }
    String details() {
        return String.format("{" +
            "\"participant\":\"%s\"," +
            "\"newScore\":%d," +
            "\"weapon\":\"%s\"," +
            "\"cx\":%f," +
            "\"cy\":%f," +
            "\"id\":%d," +
            "\"x\":%f," +
            "\"y\":%f," +
            "\"cid\":%d," +
            "\"source\":\"%s\"" +
        "}", this.participant,
             this.newScore,
             this.weapon,
             this.cx,
             this.cy,
             this.id,
             this.x,
             this.y,
             this.cid,
             this.source);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a workspace is initialized.
 */
class HybridWorkspaceInitializedEvent implements HybridTouchEvent {
    /** The participant whose workspace this is. */
    String participant;
    /** The x coordinate of the workspace's position. */
    float x;
    /** The y coordinate of the workspace's position. */
    float y;
    HybridWorkspaceInitializedEvent(String participant, float x, float y) {
        this.participant = participant;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Trial.WorkspaceInitialized";
    }
    String details() {
        return String.format("{" +
            "\"participant\":\"%s\"," +
            "\"x\":%f," +
            "\"y\":%f" +
        "}", this.participant, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a workspace is moved.
 */
class HybridWorkspaceMovedEvent implements HybridTouchEvent {
    /** The participant whose workspace moved. */
    String participant;
    /** The x coordinate of the workspace's new position. */
    float x;
    /** The y coordinate of the workspace's new position. */
    float y;
    /** The touch id used to move the workspace. */
    int cid;
    HybridWorkspaceMovedEvent(String participant, float x, float y, int cid) {
        this.participant = participant;
        this.x = x;
        this.y = y;
        this.cid = cid;
    }
    String eventType() {
        return "Trial.WorkspaceMoved";
    }
    String details() {
        return String.format("{" +
            "\"participant\":\"%s\"," +
            "\"x\":%f," +
            "\"y\":%f," +
            "\"cid\":%d" +
        "}", this.participant, this.x, this.y, this.cid);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when two workspaces are pushed away from one another.
 */
class HybridWorkspaceRestitutedEvent implements HybridTouchEvent {
    /** The participant whose workspace triggered the restitution. */
    String participant;
    /** The x coordinate of the workspace's new position. */
    float x;
    /** The y coordinate of the workspace's new position. */
    float y;
    /** The participant whose workspace was also involved in the restitution. */
    String participant2;
    /** The x coordinate of the workspace's new position. */
    float x2;
    /** The y coordinate of the workspace's new position. */
    float y2;
    HybridWorkspaceRestitutedEvent(String participant, float x, float y, 
            String participant2, float x2, float y2) {
        this.participant = participant;
        this.x = x;
        this.y = y;
        this.participant2 = participant2;
        this.x2 = x2;
        this.y2 = y2;
    }
    String eventType() {
        return "Trial.WorkspaceRestituted";
    }
    String details() {
        return String.format("{" +
            "\"participant\":\"%s\"," +
            "\"x\":%f," +
            "\"y\":%f," +
            "\"participant2\":\"%s\"," +
            "\"x2\":%f," +
            "\"y2\":%f" +
        "}", this.participant, this.x, this.y, this.participant2, this.x2, this.y2);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a workspace is pushed back into screen bounds.
 */
class HybridWorkspaceKeptOnscreenEvent implements HybridTouchEvent {
    /** The participant whose workspace was offscreen. */
    String participant;
    /** The x coordinate of the workspace's new position. */
    float x;
    /** The y coordinate of the workspace's new position. */
    float y;
    HybridWorkspaceKeptOnscreenEvent(String participant, float x, float y) {
        this.participant = participant;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Trial.WorkspaceKeptOnscreen";
    }
    String details() {
        return String.format("{" +
            "\"participant\":\"%s\"," +
            "\"x\":%f," +
            "\"y\":%f" +
        "}", this.participant, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a trial is completed. This mostly exists to ensure that the log
 * receives that final flush.
 */
class HybridTrialEndedEvent implements HybridTouchEvent {
    HybridTrialEndedEvent() {
    }
    String eventType() {
        return "Trial.Ended";
    }
    String details() {
        return "{}";
    }
    boolean isFlushEvent() { return true; }
}


/**
 * Records when a trial is resumed from a crash. Any dead zones or cursors
 * that were spawned should be assumed to no longer exist. This event is
 * mostly for the purposes of playback -- otherwise cursors might spawn
 * and never be despawned.
 */
class HybridTrialResumedEvent implements HybridTouchEvent {
    HybridTrialResumedEvent() {
    }
    String eventType() {
        return "Trial.Resumed";
    }
    String details() {
        return "{}";
    }
    boolean isFlushEvent() { return false; }
}


/**
 * A writer that prints output to a log file. The format is a series of lines:
 *      timestamp, event, JSON
 * The timestamp is the system time in milliseconds when the event occurred.
 * The event is a unique identifier saying what kind of event it is.
 * The JSON is a valid JSON string containing any parameters related to the
 * event.
 */
private class EventWriter {
    PrintWriter writer;
    List<String> buffer;
    EventWriter(String filename) {
        try {
            // Append iff file exists, create otherwise.
            File file = new File(sketchPath(filename));
            this.writer = new PrintWriter(new FileWriter(file, file.exists()));
        } catch (IOException ex) {
            println("Uncaught exception:");
            println(ex);
            System.exit(0);
        }
        this.buffer = new ArrayList<String>();
    }
    void logEvent(long timestamp, HybridTouchEvent event) {
        this.buffer.add(String.format("%d, %s, %s\n", timestamp, event.eventType(), event.details()));
        if (event.isFlushEvent()) {
            for (String line: this.buffer) {
                this.writer.print(line);
            }
            this.buffer.clear();
            this.writer.flush();
        }
    }
}


