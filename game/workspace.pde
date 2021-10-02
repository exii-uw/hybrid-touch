

private final int WORKSPACE_MID_GUTTER = 580;
private final float WORKSPACE_EDGE_GUTTER = 32;
private final float WORKSPACE_WEAPON_EDGE_GUTTER = 8;
private final float WORKSPACE_TEXT_GUTTER = 64;
private final float WORKSPACE_ROUNDED_CORNER_RADIUS = 32;
private final float WORKSPACE_MOVABLE_RADIUS = 512;
private final float WORKSPACE_MOVABLE_HANDLE_RADIUS = 64;
private final float WORKSPACE_MOVABLE_HANDLE_POSITION_X = 0;
private final float WORKSPACE_MOVABLE_HANDLE_POSITION_Y = 0;
private final float WORKSPACE_MOVABLE_RESTITUTION = 0.6;
private final float WORKSPACE_MOVABLE_EDGE_LIMIT = 64;
private PFont workspaceParticipantIdentifierFont;


private final int PARTICIPANT_SCORE_INCREMENT = 5; // How many points to gain per enemy defeated


private List<Workspace> workspaces;


public void initializeWorkspaces() {
    workspaces = new ArrayList<Workspace>();
    if (CONFIG_MOVABLE_WORKSPACES) {
        workspaces.add((Workspace) new MovableWorkspace(CONFIG_PARTICIPANTS[0], color(240, 160, 60),
                    machineScreenWidth / 4.0, machineScreenHeight / 2.0));
        workspaces.add((Workspace) new MovableWorkspace(CONFIG_PARTICIPANTS[1], color(60, 160, 240),
                    machineScreenWidth * 3.0 / 4.0, machineScreenHeight / 2.0));
    } else {
        workspaces.add((Workspace) new HalfScreenWorkspace(CONFIG_PARTICIPANTS[0], color(240, 160, 60), false));
        workspaces.add((Workspace) new HalfScreenWorkspace(CONFIG_PARTICIPANTS[1], color(60, 160, 240), true));
    }
    workspaceParticipantIdentifierFont = loadFont("3Dventure-48.vlw");
}


public void logWorkspaces() {
    for (Workspace workspace: getWorkspaces()) {
        logEvent(new HybridWorkspaceInitializedEvent(
                    workspace.participantIdentifier, workspace.getX(), workspace.getY()));
    }
}


/**
 * Return a read-only list of the workspaces in this trial. Note that while the list
 * itself should be considered read-only, you can feel free to modify the workspaces
 * within the list.
 */
public List<Workspace> getWorkspaces() {
    return workspaces;
}


/**
 * Give points to the named participant.
 *
 * @return The participant's score after the change, or -1 if the participant was not found.
 */
public int workspaceIncrementParticipantScore(String participant) {
    for (Workspace workspace: workspaces) {
        if (workspace.participantIdentifier == participant) {
            workspace.participantScore += PARTICIPANT_SCORE_INCREMENT;
            return workspace.participantScore;
        }
    }
    return -1;
}


/**
 * A workspace that defines the area in which a participant can perform touches
 * or interactions.
 */
abstract class Workspace extends InteractionListener {
    public String participantIdentifier;
    public color participantColor;
    public int participantScore;
    public int damageTaken;
    public InteractionMachine interaction;
    public Weapon weapon; /** nullable */

    private ArrayList<FilteredTouch> filteredTouches;

    public void initialize(String participantIdentifier, color participantColor) {
        this.participantIdentifier = participantIdentifier;
        this.participantColor = participantColor;
        this.participantScore = 0;
        this.damageTaken = 0;
        this.interaction = new InteractionMachine(this);
        this.filteredTouches = new ArrayList<FilteredTouch>();
    }

    /**
     * Draw the boundary of the current workspace.
     */
    void displayWorkspace() {
    }

    /**
     * Display the workspace's interaction machine.
     */
    void displayInteraction() {
        if (CONFIG_SHOW_DEAD_ZONES) {
            this.interaction.displayInteractionDeadZones();
        }

        this.interaction.displayInteraction();
    }

    /**
     * Return true if a given point is inside of this workspace.
     */
    abstract boolean pointInWorkspace(float x, float y);


    /**
     * Set the weapon this workspace is currently using.
     */
    void setWeapon(Weapon weapon) {
        this.weapon = weapon;
    }

    /**
     * Frame update.
     */
    void update() {
        this.interaction.updateInteraction();
    }


    /**
     * Cursor interaction methods. These will be called whenever
     * we get an event from the interaction machine.
     *
     * By default, we let weapons decide what happens to them when
     * they see cursor events from anyone.
     */
    void click(float x, float y, String registerClickType, int touchId, long startTime) {
        // We actually don't care about abstract clicks right now. A click caused
        // by a touch-tap should be interpreted differently from a click caused by
        // a cursor-tap.
    }
    void cursorTap(float x, float y) {
        for (Weapon weapon: weapons) {
            weapon.cursorTap(this, x, y);
        }
    }
    void cursorSpawn(float x, float y) {
        for (Weapon weapon: weapons) {
            weapon.cursorSpawn(this, x, y);
        }
    }
    void cursorMove(float x, float y) {
        for (Weapon weapon: weapons) {
            weapon.cursorMove(this, x, y);
        }
    }
    void cursorDespawn(float x, float y) {
        for (Weapon weapon: weapons) {
            weapon.cursorDespawn(this, x, y);
        }
    }

    /**
     * Respond to a touch tap event. By default, simply routes to the
     * interaction technique if the touch belongs to this workspace.
     */
    void touchTap(FilteredTouch touch) {
        if (touch.workspace == this) {
            this.interaction.touchTap(touch);
        }
    }

    /**
     * Respond to a touch down event. By default, simply routes to the
     * interaction technique if the point is inside the workspace,
     * and assigns the touch to this workspace.
     */
    void touchDown(FilteredTouch touch) {
        if (this.pointInWorkspace(touch.x, touch.y)) {
            touch.setWorkspace(this);
            this.filteredTouches.add(touch);
            this.interaction.touchDown(touch);
        }
    }

    /**
     * Respond to a touch up event. By default, simply routes to the
     * interaction technique always.
     */
    void touchUp(FilteredTouch touch) {
        this.filteredTouches.remove(touch);
        this.interaction.touchUp(touch);
    }

    /**
     * Respond to a touch move event. By default, simply routes to the
     * interaction technique if the touch belongs to this workspace.
     */
    void touchMove(FilteredTouch touch) {
        if (touch.workspace == this) {
            this.interaction.touchMove(touch);
        }
    }

    /**
     * Respond to a touch move event that cannot trigger a touch tap.
     * By default, simply routes to the interaction technique if the point is
     * inside the workspace.
     */
    void touchSignificantMove(FilteredTouch touch) {
        if (touch.workspace == this) {
            this.interaction.touchSignificantMove(touch);
        }
    }


    /**
     * Return the set of touches associated with this workspace.
     * The returned list should be considered immutable, and should not
     * be changed.
     */
    List<FilteredTouch> getFilteredTouches() {
        return this.filteredTouches;
    }


    /**
     * Return the participant identifier. Used by the implementation of
     * InteractionListener.
     */
    String participant() {
        return this.participantIdentifier;
    }


    /** Return the position of this workspace. */
    abstract float getX();
    abstract float getY();
}


/**
 * A workspace that covers the entire screen. All touch events are simply
 * routed to the interaction technique.
 */
class FullWorkspace extends Workspace {
    public FullWorkspace(String participantIdentifier, color participantColor) {
        super.initialize(participantIdentifier, participantColor);
    }

    void displayWorkspace() {
        stroke(this.participantColor);
        noFill();
        rect(WORKSPACE_EDGE_GUTTER, WORKSPACE_EDGE_GUTTER,
                machineScreenWidth - WORKSPACE_EDGE_GUTTER * 2.0,
                machineScreenHeight - WORKSPACE_EDGE_GUTTER * 2.0,
                WORKSPACE_ROUNDED_CORNER_RADIUS);
        if (this.weapon != null) {
            stroke(this.weapon.weaponColor());
            rect(WORKSPACE_EDGE_GUTTER + WORKSPACE_WEAPON_EDGE_GUTTER,
                    WORKSPACE_EDGE_GUTTER + WORKSPACE_WEAPON_EDGE_GUTTER,
                    machineScreenWidth - WORKSPACE_EDGE_GUTTER * 2.0 - WORKSPACE_WEAPON_EDGE_GUTTER * 2.0,
                    machineScreenHeight - WORKSPACE_EDGE_GUTTER * 2.0 - WORKSPACE_WEAPON_EDGE_GUTTER * 2.0,
                    WORKSPACE_ROUNDED_CORNER_RADIUS - WORKSPACE_WEAPON_EDGE_GUTTER);
        }
        textFont(workspaceParticipantIdentifierFont, 48);
        textAlign(LEFT);
        fill(this.participantColor);
        text(this.participantIdentifier, WORKSPACE_TEXT_GUTTER, WORKSPACE_TEXT_GUTTER,
                machineScreenWidth - WORKSPACE_TEXT_GUTTER * 2.0,
                machineScreenHeight - WORKSPACE_TEXT_GUTTER * 2.0);
        super.displayWorkspace();
    }

    boolean pointInWorkspace(float x, float y) {
        return true;
    }

    float getX() {
        return machineScreenWidth * 0.5;
    }

    float getY() {
        return machineScreenHeight * 0.5;
    }
}


/**
 * A workspace that covers half the screen.
 */
class HalfScreenWorkspace extends Workspace {
    boolean isRightHalf;

    public HalfScreenWorkspace(String participantIdentifier, color participantColor, boolean isRightHalf) {
        this.isRightHalf = isRightHalf;
        super.initialize(participantIdentifier, participantColor);
    }
    
    void displayWorkspace() {
        displayHalfscreenWorkspace(this.isRightHalf, this.participantColor, this.participantIdentifier,
                                   this.participantScore - this.damageTaken,
                                   this.weapon != null ? this.weapon.weaponType() : null,
                                   this.weapon != null ? this.weapon.weaponColor() : color(0));
        super.displayWorkspace();
    }

    boolean pointInWorkspace(float x, float y) {
        if (!this.isRightHalf) { // Left
            return x < machineScreenWidth / 2.0 - WORKSPACE_MID_GUTTER / 2.0;
        } else { // Right
            return x > machineScreenWidth / 2.0 + WORKSPACE_MID_GUTTER / 2.0;
        }
    }

    float getX() {
        return this.isRightHalf ? machineScreenWidth * 3.0 / 4.0 : machineScreenWidth / 4.0;
    }

    float getY() {
        return machineScreenHeight * 0.5;
    }
}


/**
 * A workspace that can be picked up and moved around.
 */
class MovableWorkspace extends Workspace {
    float x;
    float y;
    FilteredTouch holdingTouch;

    public MovableWorkspace(String participantIdentifier, color participantColor, float x, float y) {
        this.x = x;
        this.y = y;
        this.holdingTouch = null;
        super.initialize(participantIdentifier, participantColor);
    }
    
    void displayWorkspace() {
        displayMobileWorkspace(this.x, this.y, this.holdingTouch != null,
                               this.participantColor, this.participantIdentifier,
                               this.participantScore - this.damageTaken,
                               this.weapon != null ? this.weapon.weaponType() : null,
                               this.weapon != null ? this.weapon.weaponColor() : color(0));
        super.displayWorkspace();
    }

    boolean pointInWorkspace(float x, float y) {
        float dx = this.x - x;
        float dy = this.y - y;
        return dx * dx + dy * dy <= WORKSPACE_MOVABLE_RADIUS * WORKSPACE_MOVABLE_RADIUS;
    }

    void update() {
        // Extra assurance that we'll let go of the workspace if a finger is lifted,
        // even if it doesn't trigger a touchUp for some reason... I don't think this
        // is necessary, but at this point I'm happy to just be sure.
        if (this.holdingTouch != null) {
            boolean holdingTouchFound = false;
            for (FilteredTouch touch: getFilteredTouches()) {
                if (touch.id == this.holdingTouch.id) {
                    holdingTouchFound = true;
                }
            }
            if (!holdingTouchFound) {
                this.holdingTouch = null;
            } else {
                this.x = this.holdingTouch.x - WORKSPACE_MOVABLE_HANDLE_POSITION_X;
                this.y = this.holdingTouch.y - WORKSPACE_MOVABLE_HANDLE_POSITION_Y;
                logEvent(new HybridWorkspaceMovedEvent(this.participantIdentifier, this.x, this.y, this.holdingTouch.id));
            }
        }
        for (Workspace otherWorkspaceGeneric: getWorkspaces()) {
            MovableWorkspace otherWorkspace = (MovableWorkspace) otherWorkspaceGeneric;
            if (otherWorkspace != null) {
                if (this == otherWorkspace) {
                    continue;
                }
                float dx = this.x - otherWorkspace.x;
                float dy = this.y - otherWorkspace.y;
                if (dx * dx + dy * dy <= 4.0 * WORKSPACE_MOVABLE_RADIUS * WORKSPACE_MOVABLE_RADIUS) {
                    // Workspaces are overlapping. Push them apart.
                    PVector rejection = new PVector(dx, dy);
                    rejection.normalize();
                    float penetration = WORKSPACE_MOVABLE_RADIUS * 2.0 - (float) Math.sqrt(dx * dx + dy * dy);
                    rejection.mult(penetration);
                    this.x += rejection.x * 0.5 * WORKSPACE_MOVABLE_RESTITUTION;
                    this.y += rejection.y * 0.5 * WORKSPACE_MOVABLE_RESTITUTION;
                    otherWorkspace.x -= rejection.x * 0.5 * WORKSPACE_MOVABLE_RESTITUTION;
                    otherWorkspace.y -= rejection.y * 0.5 * WORKSPACE_MOVABLE_RESTITUTION;
                    logEvent(new HybridWorkspaceRestitutedEvent(
                        this.participantIdentifier, this.x, this.y,
                        otherWorkspace.participantIdentifier, otherWorkspace.x, otherWorkspace.y));
                }
            }
        }
        if (this.x < WORKSPACE_MOVABLE_EDGE_LIMIT) {
            this.x = WORKSPACE_MOVABLE_EDGE_LIMIT;
            logEvent(new HybridWorkspaceKeptOnscreenEvent(this.participantIdentifier, this.x, this.y));
        }
        if (this.y < WORKSPACE_MOVABLE_EDGE_LIMIT) {
            this.y = WORKSPACE_MOVABLE_EDGE_LIMIT;
            logEvent(new HybridWorkspaceKeptOnscreenEvent(this.participantIdentifier, this.x, this.y));
        }
        if (this.x > machineScreenWidth - WORKSPACE_MOVABLE_EDGE_LIMIT) {
            this.x = machineScreenWidth - WORKSPACE_MOVABLE_EDGE_LIMIT;
            logEvent(new HybridWorkspaceKeptOnscreenEvent(this.participantIdentifier, this.x, this.y));
        }
        if (this.y > machineScreenHeight - WORKSPACE_MOVABLE_EDGE_LIMIT) {
            this.y = machineScreenHeight - WORKSPACE_MOVABLE_EDGE_LIMIT;
            logEvent(new HybridWorkspaceKeptOnscreenEvent(this.participantIdentifier, this.x, this.y));
        }
        super.update();
    }

    void touchDown(FilteredTouch touch) {
        if (this.holdingTouch == null) {
            float dx = (this.x + WORKSPACE_MOVABLE_HANDLE_POSITION_X) - touch.x;
            float dy = (this.y + WORKSPACE_MOVABLE_HANDLE_POSITION_Y) - touch.y;
            if (dx * dx + dy * dy <= WORKSPACE_MOVABLE_HANDLE_RADIUS * WORKSPACE_MOVABLE_HANDLE_RADIUS) {
                this.holdingTouch = touch;
            }
        }
        super.touchDown(touch);
    }

    void touchUp(FilteredTouch touch) {
        if (this.holdingTouch != null && touch.id == this.holdingTouch.id) {
            this.holdingTouch = null;
        }
        super.touchUp(touch);
    }

    void touchMove(FilteredTouch touch) {
        super.touchMove(touch);
    }

    float getX() {
        return this.x;
    }

    float getY() {
        return this.y;
    }
}
