
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
    /** The scale at which this trial was run. */
    float scale;
    HybridStartupEvent(String time, String script, float scale) {
        this.time = time;
        this.script = script;
        this.scale = scale;
    }
    String eventType() {
        return "System.Startup";
    }
    String details() {
        return String.format("{\"time\":\"%s\",\"script\":\"%s\",\"scale\":%f}", this.time, this.script, this.scale);
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
    HybridCursorSpawnedEvent(int id, int count, float x, float y) {
        this.id = id;
        this.count = count;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Hybrid.CursorSpawned";
    }
    String details() {
        return String.format("{\"id\":%d,\"count\":%d,\"x\":%f,\"y\":%f}", this.id, this.count, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when the spawned cursor is moved.
 */
class HybridCursorMovedEvent implements HybridTouchEvent {
    /** The x coordinate where the cursor was moved. */
    float x;
    /** The y coordinate where the cursor was moved. */
    float y;
    HybridCursorMovedEvent(float x, float y) {
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Hybrid.CursorMoved";
    }
    String details() {
        return String.format("{\"x\":%f,\"y\":%f}", this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a cursor disappears.
 */
class HybridCursorDespawnedEvent implements HybridTouchEvent {
    HybridCursorDespawnedEvent() {
    }
    String eventType() {
        return "Hybrid.CursorDespawned";
    }
    String details() {
        return "{}";
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when the participant actively moves the screen.
 */
class HybridScreenPulledEvent implements HybridTouchEvent {
    /** The number of fingers used to move the screen. */
    int count;
    /** The x coordinate where the cursor was spawned. */
    float x;
    /** The y coordinate where the cursor was spawned. */
    float y;
    HybridScreenPulledEvent(int count, float x, float y) {
        this.count = count;
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Hybrid.ScreenPulled";
    }
    String details() {
        return String.format("{\"count\":%d,\"x\":%f,\"y\":%f}", this.count, this.x, this.y);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when the screen moves toward its resting position.
 */
class HybridScreenResetEvent implements HybridTouchEvent {
    /** The x coordinate where the cursor was spawned. */
    float x;
    /** The y coordinate where the cursor was spawned. */
    float y;
    HybridScreenResetEvent(float x, float y) {
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Hybrid.ScreenReset";
    }
    String details() {
        return String.format("{\"x\":%f,\"y\":%f}", this.x, this.y);
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
 * Records when the current interaction mode changes.
 */
class HybridInteractionModeChangedEvent implements HybridTouchEvent {
    /** The mode being switched to. */
    String mode;
    HybridInteractionModeChangedEvent(String mode) {
        this.mode = mode;
    }
    String eventType() {
        return "Trial.InteractionModeChanged";
    }
    String details() {
        return String.format("{\"mode\":\"%s\"}", this.mode);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when the current interaction mode changes.
 */
class HybridTargetWidthChangedEvent implements HybridTouchEvent {
    /** The width of newly spawned targets. */
    int width;
    HybridTargetWidthChangedEvent(int width) {
        this.width = width;
    }
    String eventType() {
        return "Trial.TargetWidthChanged";
    }
    String details() {
        return String.format("{\"width\":\"%d\"}", this.width);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a run of 13 targets (1 discarded then 12 real) begins.
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
 * Records when a run of blocks of every width and distance begins.
 */
class HybridBeginBigBlockEvent implements HybridTouchEvent {
    int standingPosition;
    HybridBeginBigBlockEvent(int standingPosition) {
        this.standingPosition = standingPosition;
    }
    String eventType() {
        return "Trial.BeginBigBlock";
    }
    String details() {
        return String.format("{\"standing_position\":\"%d\"}", this.standingPosition);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a target is spawned that we don't want to consider in our
 * analysis. Each run starts with a discarded target, because it won't have
 * a consistent distance on the boundary of a run.
 */
class HybridDiscardedTargetSpawnedEvent implements HybridTouchEvent {
    /** The x coordinate of the centre point of the target. */
    float tx;
    /** The y coordinate of the centre point of the target. */
    float ty;
    /** The width of the target that was hit. */
    float tw;
    /** The height of the target that was hit. */
    float th;
    HybridDiscardedTargetSpawnedEvent(float tx, float ty, float tw, float th) {
        this.tx = tx;
        this.ty = ty;
        this.tw = tw;
        this.th = th;
    }
    String eventType() {
        return "Trial.DiscardedTargetSpawned";
    }
    String details() {
        return String.format("{\"tx\":%f,\"ty\":%f,\"tw\":%f,\"th\":%f}", this.tx, this.ty, this.tw, this.th);
    }
    boolean isFlushEvent() { return true; }
}


/**
 * Records when a target is spawned.
 */
class HybridTargetSpawnedEvent implements HybridTouchEvent {
    /** The x coordinate of the centre point of the target. */
    float tx;
    /** The y coordinate of the centre point of the target. */
    float ty;
    /** The width of the target that was hit. */
    float tw;
    /** The height of the target that was hit. */
    float th;
    HybridTargetSpawnedEvent(float tx, float ty, float tw, float th) {
        this.tx = tx;
        this.ty = ty;
        this.tw = tw;
        this.th = th;
    }
    String eventType() {
        return "Trial.TargetSpawned";
    }
    String details() {
        return String.format("{\"tx\":%f,\"ty\":%f,\"tw\":%f,\"th\":%f}", this.tx, this.ty, this.tw, this.th);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a target is spawned as part of target practice.
 */
class HybridTargetPracticeSpawnedEvent extends HybridTargetSpawnedEvent {
    HybridTargetPracticeSpawnedEvent(float tx, float ty, float tw, float th) {
        super(tx, ty, tw, th);
    }
    String eventType() {
        return "Practice.TargetSpawned";
    }
}


/**
 * Records when a target indicator is spawned.
 */
class HybridTargetIndicatorSpawnedEvent implements HybridTouchEvent {
    /** The id of this indicator. */
    int id;
    /** The x coordinate of the centre point of the indicator. */
    float tx;
    /** The y coordinate of the centre point of the indicator. */
    float ty;
    /** The width of the indicator. */
    float tw;
    /** The height of the indicator. */
    float th;
    HybridTargetIndicatorSpawnedEvent(int id, float tx, float ty, float tw, float th) {
        this.id = id;
        this.tx = tx;
        this.ty = ty;
        this.tw = tw;
        this.th = th;
    }
    String eventType() {
        return "Trial.TargetIndicatorSpawned";
    }
    String details() {
        return String.format("{\"id\":%d,\"tx\":%f,\"ty\":%f,\"tw\":%f,\"th\":%f}",
                this.id,
                this.tx,
                this.ty,
                this.tw,
                this.th);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a target indicator is hidden.
 */
class HybridTargetIndicatorHiddenEvent implements HybridTouchEvent {
    /** The id of this indicator. */
    int id;
    HybridTargetIndicatorHiddenEvent(int id) {
        this.id = id;
    }
    String eventType() {
        return "Trial.TargetIndicatorHidden";
    }
    String details() {
        return String.format("{\"id\":%d}", this.id);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when the standing position indicator is shown.
 */
class HybridStandingPositionIndicatorShownEvent implements HybridTouchEvent {
    /** The x coordinate of the centre point of the indicator. */
    float x;
    HybridStandingPositionIndicatorShownEvent(float x) {
        this.x = x;
    }
    String eventType() {
        return "Trial.StandingPositionIndicatorShown";
    }
    String details() {
        return String.format("{\"x\":%f}", this.x);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when the standing position indicator is hidden.
 */
class HybridStandingPositionIndicatorHiddenEvent implements HybridTouchEvent {
    /** The x coordinate of the centre point of the indicator. */
    HybridStandingPositionIndicatorHiddenEvent() { }
    String eventType() {
        return "Trial.StandingPositionIndicatorHidden";
    }
    String details() {
        return "{}";
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a target has been hit.
 */
class HybridTargetHitEvent implements HybridTouchEvent {
    /** A string describing how the target was clicked. */
    String source;
    /**
     * The unique identifier assigned to the touch by the input driver, if
     * this event was generated by a finger touch. Otherwise, an undefined
     * value.
     */
    int id;
    /** The x coordinate where the click occured that hit the target. */
    float x;
    /** The y coordinate where the click occured that hit the target. */
    float y;
    /** The x coordinate of the centre point of the target. */
    float tx;
    /** The y coordinate of the centre point of the target. */
    float ty;
    /** The width of the target that was hit. */
    float tw;
    /** The height of the target that was hit. */
    float th;
    HybridTargetHitEvent(String source, int id, float x, float y, float tx, float ty, float tw, float th) {
        this.source = source;
        this.id = id;
        this.x = x;
        this.y = y;
        this.tx = tx;
        this.ty = ty;
        this.tw = tw;
        this.th = th;
    }
    String eventType() {
        return "Trial.TargetHit";
    }
    String details() {
        return String.format("{\"source\":\"%s\",\"id\":%d,\"x\":%f,\"y\":%f,\"tx\":%f,\"ty\":%f,\"tw\":%f,\"th\":%f}",
                this.source, this.id, this.x, this.y, this.tx, this.ty, this.tw, this.th);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a target is hit as part of target practice.
 */
class HybridTargetPracticeHitEvent extends HybridTargetHitEvent {
    HybridTargetPracticeHitEvent(String source, int id, float x, float y, float tx, float ty, float tw, float th) {
        super(source, id, x, y, tx, ty, tw, th);
    }
    String eventType() {
        return "Practice.TargetHit";
    }
}


/**
 * Records when a target has been missed.
 */
class HybridTargetMissedEvent implements HybridTouchEvent {
    /** A string describing how the click occurred. */
    String source;
    /**
     * The unique identifier assigned to the touch by the input driver, if
     * this event was generated by a finger touch. Otherwise, an undefined
     * value.
     */
    int id;
    /** The x coordinate where the click occured that missed the target. */
    float x;
    /** The y coordinate where the click occured that missed the target. */
    float y;
    /** The x coordinate of the centre point of the target. */
    float tx;
    /** The y coordinate of the centre point of the target. */
    float ty;
    /** The width of the target that was hit. */
    float tw;
    /** The height of the target that was hit. */
    float th;
    HybridTargetMissedEvent(String source, int id, float x, float y, float tx, float ty, float tw, float th) {
        this.source = source;
        this.id = id;
        this.x = x;
        this.y = y;
        this.tx = tx;
        this.ty = ty;
        this.tw = tw;
        this.th = th;
    }
    String eventType() {
        return "Trial.TargetMissed";
    }
    String details() {
        return String.format("{\"source\":\"%s\",\"id\":%d,\"x\":%f,\"y\":%f,\"tx\":%f,\"ty\":%f,\"tw\":%f,\"th\":%f}",
                this.source, this.id, this.x, this.y, this.tx, this.ty, this.tw, this.th);
    }
    boolean isFlushEvent() { return false; }
}


/**
 * Records when a target is missed as part of target practice.
 */
class HybridTargetPracticeMissedEvent extends HybridTargetMissedEvent {
    HybridTargetPracticeMissedEvent(String source, int id, float x, float y, float tx, float ty, float tw, float th) {
        super(source, id, x, y, tx, ty, tw, th);
    }
    String eventType() {
        return "Practice.TargetMissed";
    }
}


/**
 * Records the estimated location of the participant at the current time. Since the participant is a three-dimensional
 * object, it does not really have a specific position. The estimated location is meant to be a measure of how far
 * away the target is from the participant, and is guessed as the centre of the bounding box containing all of the
 * participant's active touches when a cursor is spawned.
 */
class HybridParticipantLocationEstimatedEvent implements HybridTouchEvent {
    /** The x coordinate of the participant. */
    float x;
    /** The y coordinate of the participant. */
    float y;
    HybridParticipantLocationEstimatedEvent(float x, float y) {
        this.x = x;
        this.y = y;
    }
    String eventType() {
        return "Hybrid.ParticipantLocationEstimated";
    }
    String details() {
        return String.format("{\"x\":%f,\"y\":%f}", this.x, this.y);
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


