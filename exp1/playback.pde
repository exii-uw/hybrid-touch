

List<PlaybackLogEvent> logEvents = null;
int logEventCursor = 0;


private float playbackMachineTrialScale = 1.0;
private float playbackScreenX;
private float playbackScreenY;
private float playbackTargetX;
private float playbackTargetY;
private float playbackTargetWidth;
private float playbackTargetHeight;
private boolean playbackTargetShowing = false;
private float playbackCursorOriginX;
private float playbackCursorOriginY;
private float playbackCursorX;
private float playbackCursorY;
private boolean playbackCursorShowing = false;
private float playbackParticipantX;
private float playbackParticipantY;
private boolean playbackStandingPositionIndicatorShowing = false;
private float playbackStandingPositionIndicatorX;
private List<PlaybackTouch> playbackTouches;
private List<PlaybackTouch> playbackRawTouches;
private List<PlaybackTouch> playbackDeadTouches;
private List<PlaybackDeadZone> playbackDeadZones;


void startPlayback(String logPath, float playbackSpeed, long playbackStart) {
    JSONParser parser = new JSONParser();
    logEvents = new ArrayList<PlaybackLogEvent>();
    String[] strings = loadStrings(logPath);
    int line = 1;
    try {
        for (String string: strings) {
            int comma = string.indexOf(',');
            String eventTimeString = string.substring(0, comma);
            long eventTime = Long.parseLong(eventTimeString);
            String eventNameAndDataString = string.substring(comma + 2);
            int secondComma = eventNameAndDataString.indexOf(',');
            String eventName = eventNameAndDataString.substring(0, secondComma);
            String eventDataString = eventNameAndDataString.substring(secondComma + 1);
            JSONObject eventData = (JSONObject) parser.parse(eventDataString);
            logEvents.add(new PlaybackLogEvent(eventTime, eventName, eventData));
        }
        System.out.printf("Loading log %s\n", logPath);
        ++line;
    } catch (ParseException e) {
        println(e);
        System.out.printf("failed to parse log %s at line %d\n", logPath, line);
        System.exit(1);
    }
    Collections.sort(logEvents);
    long programStartTime = System.currentTimeMillis();
    long logStartTime = playbackStart == 0 ? logEvents.get(0).timestamp : playbackStart;
    // Convert all events into program-relative times.
    for (PlaybackLogEvent event: logEvents) {
        event.timestamp = ((long) ((event.timestamp - logStartTime) / playbackSpeed)) + programStartTime;
    }
    playbackTouches = new ArrayList();
    playbackRawTouches = new ArrayList();
    playbackDeadTouches = new ArrayList();
    playbackDeadZones = new ArrayList();
}


void displayPlayback() {
    if (logEventCursor < logEvents.size()) {
        long time = System.currentTimeMillis();
        PlaybackLogEvent currentEvent;
        while (logEventCursor < logEvents.size() &&
               (currentEvent = (PlaybackLogEvent) logEvents.get(logEventCursor)).timestamp < time) {
            JSONObject data = currentEvent.data;
            System.out.printf("%d, %s\n", currentEvent.timestamp, currentEvent.name);
            if (currentEvent.name.equals("System.Startup")) {
                playbackMachineTrialScale = machineTrialScale / (float) (((Number) data.get("scale")).doubleValue());
            } else if (currentEvent.name.equals("Input.TouchDown")) {
                int id = (int) ((Number) data.get("id")).intValue();
                float x = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                float y = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
                playbackTouches.add(new PlaybackTouch(id, x, y));
            } else if (currentEvent.name.equals("Input.TouchMove")) {
                int id = (int) ((Number) data.get("id")).intValue();
                float x = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                float y = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
                for (PlaybackTouch touch: playbackTouches) {
                    if (touch.id == id) {
                        touch.x = x;
                        touch.y = y;
                    }
                }
            } else if (currentEvent.name.equals("Input.TouchUp")) {
                int id = (int) ((Number) data.get("id")).intValue();
                PlaybackTouch touchToRemove = null;
                for (PlaybackTouch touch: playbackTouches) {
                    if (touch.id == id) {
                        touchToRemove = touch;
                        break;
                    }
                }
                playbackTouches.remove(touchToRemove);
                touchToRemove = null;
                for (PlaybackTouch touch: playbackDeadTouches) {
                    if (touch.id == id) {
                        touchToRemove = touch;
                        break;
                    }
                }
                playbackDeadTouches.remove(touchToRemove);
            } else if (currentEvent.name.equals("Input.RawTouchDown")) {
                int id = (int) ((Number) data.get("id")).intValue();
                float x = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                float y = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
                playbackRawTouches.add(new PlaybackTouch(id, x, y));
            } else if (currentEvent.name.equals("Input.RawTouchMove")) {
                int id = (int) ((Number) data.get("id")).intValue();
                float x = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                float y = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
                for (PlaybackTouch touch: playbackRawTouches) {
                    if (touch.id == id) {
                        touch.x = x;
                        touch.y = y;
                    }
                }
            } else if (currentEvent.name.equals("Input.RawTouchUp")) {
                int id = (int) ((Number) data.get("id")).intValue();
                PlaybackTouch touchToRemove = null;
                for (PlaybackTouch touch: playbackRawTouches) {
                    if (touch.id == id) {
                        touchToRemove = touch;
                        break;
                    }
                }
                playbackRawTouches.remove(touchToRemove);
            } else if (currentEvent.name.equals("Trial.TargetSpawned")
                    || currentEvent.name.equals("Trial.DiscardedTargetSpawned")
                    || currentEvent.name.equals("Practice.TargetSpawned")) {
                float previousPlaybackTargetX = playbackTargetX;
                float previousPlaybackTargetY = playbackTargetY;
                playbackTargetX = (float) (((Number) data.get("tx")).doubleValue() * playbackMachineTrialScale);
                playbackTargetY = (float) (((Number) data.get("ty")).doubleValue() * playbackMachineTrialScale);
                playbackTargetWidth = (float) (((Number) data.get("tw")).doubleValue() * playbackMachineTrialScale);
                playbackTargetHeight = (float) (((Number) data.get("th")).doubleValue() * playbackMachineTrialScale);
                playbackTargetShowing = true;
                if (previousPlaybackTargetX != 0 && previousPlaybackTargetY != 0) {
                    createAnimation(new TargetMoveAnimation(previousPlaybackTargetX + playbackScreenX,
                                                            previousPlaybackTargetY + playbackScreenY,
                                                            playbackTargetX + playbackScreenX,
                                                            playbackTargetY + playbackScreenY));
                }
                createAnimation(new TargetSpawnAnimation(playbackTargetX + playbackScreenX,
                                                         playbackTargetY + playbackScreenY,
                                                         playbackTargetWidth,
                                                         playbackTargetHeight));
            } else if (currentEvent.name.equals("Trial.TargetHit")
                    || currentEvent.name.equals("Practice.TargetHit")) {
                playSoundTargetHit();
                createAnimation(new TargetHitAnimation(playbackTargetX + playbackScreenX,
                                                       playbackTargetY + playbackScreenY,
                                                       playbackTargetWidth,
                                                       playbackTargetHeight));
                playbackTargetShowing = false;
            } else if (currentEvent.name.equals("Trial.TargetMissed")
                    || currentEvent.name.equals("Practice.TargetMissed")) {
                playSoundTargetMissed();
                createAnimation(new TargetMissedAnimation(playbackTargetX + playbackScreenX,
                                                          playbackTargetY + playbackScreenY,
                                                          playbackTargetWidth,
                                                          playbackTargetHeight));
            } else if (currentEvent.name.equals("Hybrid.CursorSpawned")) {
                playbackCursorShowing = true;
                playbackCursorX = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                playbackCursorY = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
                playbackCursorOriginX = playbackCursorX;
                playbackCursorOriginY = playbackCursorY;
            } else if (currentEvent.name.equals("Hybrid.CursorMoved")) {
                playbackCursorX = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                playbackCursorY = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
            } else if (currentEvent.name.equals("Hybrid.CursorDespawned")) {
                playbackCursorShowing = false;
            } else if (currentEvent.name.equals("Hybrid.FingerKilled")) {
                int id = (int) ((Number) data.get("id")).intValue();
                playbackDeadTouches.add(new PlaybackTouch(id, 0, 0));
            } else if (currentEvent.name.equals("Hybrid.ScreenPulled")) {
                playbackScreenX = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                playbackScreenY = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
            } else if (currentEvent.name.equals("Hybrid.ScreenReset")) {
                playbackScreenX = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                playbackScreenY = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
            } else if (currentEvent.name.equals("Hybrid.DeadZoneSpawned")) {
                int id = (int) ((Number) data.get("id")).intValue();
                float x = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                float y = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
                float radius = (float) (((Number) data.get("radius")).doubleValue() * playbackMachineTrialScale);
                playbackDeadZones.add(new PlaybackDeadZone(id, x, y, radius));
            } else if (currentEvent.name.equals("Hybrid.DeadZoneChanged")) {
                int id = (int) ((Number) data.get("id")).intValue();
                float x = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                float y = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
                float radius = (float) (((Number) data.get("radius")).doubleValue() * playbackMachineTrialScale);
                for (PlaybackDeadZone deadZone: playbackDeadZones) {
                    if (deadZone.id == id) {
                        deadZone.x = x;
                        deadZone.y = y;
                        deadZone.radius = radius;
                    }
                }
            } else if (currentEvent.name.equals("Hybrid.DeadZoneDespawned")) {
                int id = (int) ((Number) data.get("id")).intValue();
                PlaybackDeadZone deadZoneToRemove = null;
                for (PlaybackDeadZone deadZone: playbackDeadZones) {
                    if (deadZone.id == id) {
                        deadZoneToRemove = deadZone;
                    }
                }
                playbackDeadZones.remove(deadZoneToRemove);
            } else if (currentEvent.name.equals("Hybrid.ParticipantLocationEstimated")) {
                playbackParticipantX = (float) (((Number) data.get("x")).doubleValue() * playbackMachineTrialScale);
                playbackParticipantY = (float) (((Number) data.get("y")).doubleValue() * playbackMachineTrialScale);
            } else if (currentEvent.name.equals("Trial.StandingPositionIndicatorShown")) {
                playbackStandingPositionIndicatorShowing = true;
                playbackStandingPositionIndicatorX = (float) (((Number)
                            data.get("x")).doubleValue() * playbackMachineTrialScale);
                createAnimation(new StandingPositionIndicatorSpawnAnimation(playbackStandingPositionIndicatorX));
            } else if (currentEvent.name.equals("Trial.StandingPositionIndicatorHidden")) {
                createAnimation(new StandingPositionIndicatorDespawnAnimation(playbackStandingPositionIndicatorX));
                playbackStandingPositionIndicatorShowing = false;
            } else if (currentEvent.name.equals("Trial.Resumed")) {
                playbackTargetShowing = false;
                playbackCursorShowing = false;
                playbackStandingPositionIndicatorShowing = false;
                playbackTouches.clear();
                playbackDeadTouches.clear();
                playbackDeadZones.clear();
                playbackScreenX = 0.0;
                playbackScreenY = 0.0;
            }
            ++logEventCursor;
        }
    }
    for (PlaybackDeadZone deadZone: playbackDeadZones) {
        displayDebugDeadZone(deadZone.x, deadZone.y, deadZone.radius, 1.0);
    }
    if (playbackTargetShowing == true) {
        displayTarget(playbackTargetX + playbackScreenX,
                      playbackTargetY + playbackScreenY,
                      playbackTargetWidth,
                      playbackTargetHeight);
    }
    for (PlaybackTouch touch: playbackTouches) {
        boolean dead = false;
        for (PlaybackTouch deadTouch: playbackDeadTouches) {
            if (deadTouch.id == touch.id) {
                dead = true;
            }
        }
        if (!dead) {
            displayDebugFilteredTouch(touch.x, touch.y, true);
        } else {
            displayDebugLiftedTouch(touch.x, touch.y);
        }
    }
    for (PlaybackTouch touch: playbackRawTouches) {
        displayDebugRawTouch(touch.x, touch.y);
    }
    if (playbackCursorShowing == true) {
        float cursorDistanceX = playbackCursorX - playbackCursorOriginX;
        float cursorDistanceY = playbackCursorY - playbackCursorOriginY;
        float cursorDistance = (float) Math.sqrt(cursorDistanceX * cursorDistanceX + cursorDistanceY * cursorDistanceY)
            / machineScreenWidth * playbackMachineTrialScale;
        displayCursor(playbackCursorX, playbackCursorY, cursorDistance);
        displayParticipantLocation(playbackParticipantX, playbackParticipantY);
    }
    if (playbackStandingPositionIndicatorShowing == true) {
        displayStandingPositionIndicator(playbackStandingPositionIndicatorX);
    }
    displayScreenBoundaries(playbackScreenX, playbackScreenY);
    displayAnimations();
}


/**
 * A touch being kept track of during playback.
 */
class PlaybackTouch {
    int id;
    float x;
    float y;
    PlaybackTouch(int id, float x, float y) {
        this.id = id;
        this.x = x;
        this.y = y;
    }
}


/**
 * A dead zone being kept track of during playback.
 */
class PlaybackDeadZone {
    int id;
    float x;
    float y;
    float radius;
    PlaybackDeadZone(int id, float x, float y, float radius) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.radius = radius;
    }
}


/**
 * An event from a logfile being read during playback.
 */
class PlaybackLogEvent implements Comparable<PlaybackLogEvent> {
    long timestamp;
    String name;
    JSONObject data;
    PlaybackLogEvent(long timestamp, String name, JSONObject data) {
        this.timestamp = timestamp;
        this.name = name;
        this.data = data;
    }
    int compareTo(PlaybackLogEvent other) {
        long difference = this.timestamp - other.timestamp;
        return difference > 0 ? 1 : difference < 0 ? -1 : 0;
    }
}
