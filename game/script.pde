
import java.io.StringReader;
import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonReader;
import javax.json.JsonException;


private int scriptEventIndex = 0; // The index of the next unprocessed script event
private List<ScriptEvent> scriptEvents; // The events from the script
private int lastStringLineLength = 0;


/**
 * Load a script that will run the trial.
 */
void loadScript(String scriptPath) {
    JSONParser parser = new JSONParser();
    scriptEvents = new ArrayList<ScriptEvent>();
    String[] strings = loadStrings(scriptPath);
    try {
        for (String string: strings) {
            int comma = string.indexOf(',');
            String eventName = string.substring(0, comma);
            String eventDataString = string.substring(comma + 1);
            JsonReader reader = Json.createReader(new StringReader(eventDataString));
            JsonObject eventData = reader.readObject();
            reader.close();
            scriptEvents.add(new ScriptEvent(eventName, eventData));
        }
        System.out.printf("Loading script %s\n", scriptPath);
    } catch (JsonException e) {
        System.out.printf("failed to load script %s\n", scriptPath);
        System.out.println(e);
        System.exit(1);
    }
}


/**
 * Return the next unread script event, or null if all events have been read.
 * Guaranteed to continue returning null even if called multiple times after
 * reading all events.
 * @return the next unread script event
 */
ScriptEvent readNextScriptEvent() {
    if (scriptEventIndex < scriptEvents.size()) {
        for (int i = 0; i < lastStringLineLength; ++i) {
            System.out.printf("\b");
        }
        String output = String.format("Reading script event: %d", scriptEventIndex);
        lastStringLineLength = output.length();
        System.out.printf(output);
        return scriptEvents.get(scriptEventIndex++);
    } else {
        return null;
    }
}


/**
 * An event parsed from a script file.
 */
class ScriptEvent {
    /** an identifier for the event */
    String name;
    /** the arbitrary data associated with the event */
    JsonObject data;
    ScriptEvent(String name, JsonObject data) {
        this.name = name;
        this.data = data;
    }
}
