
private Weapon[] weapons;

private final float TWO_PI = (float) Math.PI * 2.0;
private final float DEGREES = (float) Math.PI / 180.0;
private final float WEAPON_STORE_MARGIN_EDGE = 160.0;
private final float WEAPON_STORE_MARGIN_EARTH = 88.0;
private final float WEAPON_RADIUS = 128.0;
private final float WEAPON_POINT_RADIUS = 16.0;
private final float WEAPON_THICKNESS = 12.0;
private final float WEAPON_ELLIPSE_SIZE = WEAPON_RADIUS * 2.0 - WEAPON_THICKNESS;
private final float WEAPON_ANIMATION_ANGLE_DELTA = TWO_PI / 60.0 / 24.0 * 1.5;
private final float WEAPON_ANIMATION_ANGLE_DELTA_IN_USE = TWO_PI / 60.0 / 2.0;
private final float WEAPON_SNAP_SPEED = 0.9;
private final float CANNON_WEAPON_ARC = (90.0 - 10.0) * DEGREES;
private final float CANNON_WEAPON_ARC_INNER = (90.0 - 15.0) * DEGREES;
private final float CANNON_WEAPON_BLAST_RADIUS = WEAPON_RADIUS;
private final float SHIELD_WEAPON_ARC = 120.0 * DEGREES;
private final float SHIELD_WEAPON_SIDE_ARC_BEGIN = (60.0 + 2.0) * DEGREES;
private final float SHIELD_WEAPON_SIDE_ARC_END = (60.0 + 15.0) * DEGREES;
private final float SHIELD_WEAPON_SIDE_ARC_END_GAIN = 5.0 * DEGREES;
private final int BLACKHOLE_WEAPON_TAIL_SIZE = 120;
private final float BLACKHOLE_WEAPON_ARC = (120.0 - 50.0) * DEGREES;
private final float BLACKHOLE_WEAPON_ARC_INNER_OFFSET = 15.0 * DEGREES;
private final float MAGNET_WEAPON_ARC = 60.0 * DEGREES;
private final float MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN = 2.0 * DEGREES;
private final float MAGNET_WEAPON_SIDE_ARC_ADD_END = 8.0 * DEGREES;
public float weaponRadius;
public float weaponEllipseSize;
public float weaponThickness;


private class WeaponState { public String id; WeaponState(String id) { this.id = id; } }
private final WeaponState WEAPONSTATE_INACTIVE = new WeaponState("WeaponState.Inactive");
private final WeaponState WEAPONSTATE_INACTIVE_HELD = new WeaponState("WeaponState.InactiveHeld");
private final WeaponState WEAPONSTATE_ACTIVE_HOLDOVER = new WeaponState("WeaponState.ActiveHoldover");
private final WeaponState WEAPONSTATE_ACTIVE = new WeaponState("WeaponState.Active");
private final WeaponState WEAPONSTATE_ACTIVE_IN_USE = new WeaponState("WeaponState.ActiveInUse");

private PVector[] weaponStores;

void initializeWeapons() {
    weaponRadius = WEAPON_RADIUS * machineTrialScale;
    weaponEllipseSize = WEAPON_ELLIPSE_SIZE * machineTrialScale;
    weaponThickness = WEAPON_THICKNESS * machineTrialScale;
    float midline = machineScreenWidth / 2.0;
    float top = WEAPON_RADIUS + WEAPON_STORE_MARGIN_EDGE;
    float bottom = machineScreenHeight / 2.0 - earthRadius - WEAPON_RADIUS - WEAPON_STORE_MARGIN_EARTH;

    weaponStores = new PVector[] {
        new PVector(midline, top),
        new PVector(midline, bottom),
        new PVector(midline, machineScreenHeight - bottom),
        new PVector(midline, machineScreenHeight - top)
    };

    weapons = new Weapon[] {
        (Weapon) new CannonWeapon(weaponStores[0]),
        (Weapon) new ShieldWeapon(weaponStores[1]),
        (Weapon) new BlackHoleWeapon(weaponStores[2]),
        (Weapon) new MagnetWeapon(weaponStores[3])
    };
}


void displayWeapons() {
    for (PVector weaponStore: weaponStores) {
        displayWeaponStore(weaponStore.x, weaponStore.y);
    }
    for (Weapon weapon: weapons) {
        weapon.display();
    }
}


void updateWeapons() {
    for (Weapon weapon: weapons) {
        weapon.update();
    }
}


abstract class Weapon {
    public float x;
    public float y;
    public float lastX;
    public float lastY;
    public float lastWorkspaceX;
    public float lastWorkspaceY;
    public WeaponState state;
    
    /** The workspace that this weapon currently belongs to. nullable, if the weapon is not in use. */
    public Workspace workspace;

    /** A value used for animation. */
    protected float animationAngle;

    /** The touch that's holding this weapon. nullable, if the weapon is not held. */
    protected FilteredTouch holdingTouch;

    /** Where the weapon is drawn. */
    protected float visualX;
    protected float visualY;

    /** The store where this weapon is currently being kept, if any. nullable, if the weapon is not in a store. */
    protected PVector weaponStore;
    
    public Weapon(PVector weaponStore) {
        this.weaponStore = weaponStore;
        this.x = this.weaponStore.x;
        this.y = this.weaponStore.y;
        this.state = WEAPONSTATE_INACTIVE;
        this.workspace = null;
        this.animationAngle = 0.0;
        this.holdingTouch = null;
        this.visualX = this.weaponStore.x;
        this.visualY = this.weaponStore.y;
    }

    /** Get the colour of this weapon. This frankly should be static, but Java sucks, so that isn't possible. */
    public abstract color weaponColor();

    /** Get the name of this weapon. */
    public abstract String weaponType();

    /** Show this weapon on the screen. */
    public void display() {
        fill(this.weaponColor());
        noStroke();
        ellipse(this.x, this.y, WEAPON_POINT_RADIUS, WEAPON_POINT_RADIUS);
        strokeWeight(STROKE_WEIGHT);
        if (this.workspace != null) {
            noFill();
            stroke(this.workspace.participantColor);
            ellipse(this.x, this.y, WEAPON_RADIUS, WEAPON_RADIUS);
        }
    }

    /** Change the state of the weapon and log its new state. */
    protected void stateChange(WeaponState state) {
        this.state = state;
        logEvent(new HybridWeaponChanged("Weapon." + this.weaponType(),
                    this.workspace != null ? this.workspace.participantIdentifier : "",
                    this.holdingTouch != null ? this.holdingTouch.id : 0,
                    this.state.id));
        if (state == WEAPONSTATE_INACTIVE || state == WEAPONSTATE_ACTIVE) {
            this.holdingTouch = null;
        }
    }

    /** Move the weapon and log its new position. */
    protected void move(float x, float y) {
        if (x < IGNORE_BORDER) {
            x = IGNORE_BORDER;
        }
        if (x > machineScreenWidth - IGNORE_BORDER) {
            x = machineScreenWidth - IGNORE_BORDER;
        }
        if (y < IGNORE_BORDER) {
            y = IGNORE_BORDER;
        }
        if (y > machineScreenHeight - IGNORE_BORDER) {
            y = machineScreenHeight - IGNORE_BORDER;
        }
        this.x = x;
        this.y = y;
        logEvent(new HybridWeaponMoved("Weapon." + this.weaponType(), this.x, this.y));
    }

    /** Update this weapon. */
    public void update() {
        this.visualX = this.visualX + (this.x - this.visualX) * WEAPON_SNAP_SPEED;
        this.visualY = this.visualY + (this.y - this.visualY) * WEAPON_SNAP_SPEED;
        if (this.state == WEAPONSTATE_ACTIVE_IN_USE || this.state == WEAPONSTATE_INACTIVE_HELD) {
            this.animationAngle = (this.animationAngle + WEAPON_ANIMATION_ANGLE_DELTA_IN_USE) % TWO_PI;
        } else if (this.state == WEAPONSTATE_ACTIVE) {
            this.animationAngle = (this.animationAngle + WEAPON_ANIMATION_ANGLE_DELTA) % TWO_PI;
        } else {
            // Don't animate at all.
        }
        if (this.state == WEAPONSTATE_INACTIVE_HELD) {
            for (FilteredTouch touch: getFilteredTouches()) {
                if (touch == this.holdingTouch) {
                    return;
                }
            }
            this.stateChange(WEAPONSTATE_INACTIVE);
            this.placeInWeaponStore();
        } else if (this.state == WEAPONSTATE_ACTIVE_HOLDOVER) {
            this.stateChange(WEAPONSTATE_ACTIVE_IN_USE);
        }
    };

    void cursorSpawn(Workspace workspace, float x, float y) {
        boolean canBeUsed = this.state == WEAPONSTATE_ACTIVE || (
            this.state == WEAPONSTATE_ACTIVE_IN_USE && this.holdingTouch != null);
        boolean correctWorkspace = this.workspace == workspace;
        if (canBeUsed && correctWorkspace) {
            this.holdingTouch = null;
            this.stateChange(WEAPONSTATE_ACTIVE_IN_USE);
            this.move(x, y);
        }
    }

    void cursorMove(Workspace workspace, float x, float y) {
        if (this.state == WEAPONSTATE_ACTIVE_IN_USE && this.workspace == workspace
                && this.holdingTouch == null) {
            this.move(x, y);
        }
    }

    void cursorDespawn(Workspace workspace, float x, float y) {
        if (this.state == WEAPONSTATE_ACTIVE_IN_USE && this.workspace == workspace) {
            this.stateChange(WEAPONSTATE_ACTIVE);
        }
    }

    void cursorTap(Workspace workspace, float x, float y) {
        if (this.state == WEAPONSTATE_INACTIVE) {
            float dx = x - this.x;
            float dy = y - this.y;
            if (dx * dx + dy * dy < weaponRadius * weaponRadius) {
                if (workspace.weapon != null) {
                    if (workspace.weapon.state == WEAPONSTATE_ACTIVE_HOLDOVER) {
                        // This is basically just a hack to stop you from re-selecting the
                        // same weapon as we iterate over them.
                        return;
                    }
                    workspace.weapon.workspace = null;
                    workspace.weapon.state = WEAPONSTATE_INACTIVE;
                    workspace.weapon.placeInWeaponStore();
                    workspace.weapon.deactivate();
                }
                this.workspace = workspace;
                workspace.setWeapon(this);
                this.weaponStore = null;
                this.stateChange(WEAPONSTATE_ACTIVE_HOLDOVER);
                this.move(x, y);
                this.activate();
            }
        }
    }

    void touchTap(FilteredTouch touch) {
    }

    void touchDown(FilteredTouch touch) {
        this.lastX = touch.x;
        this.lastY = touch.y;
        if (this.workspace != null && this.workspace.pointInWorkspace(touch.x, touch.y)) {
            this.lastWorkspaceX = touch.x;
            this.lastWorkspaceY = touch.y;
        }
        if (this.state == WEAPONSTATE_INACTIVE || this.state == WEAPONSTATE_ACTIVE) {
            for (Weapon weapon: weapons) {
                if (weapon.holdingTouch == touch) {
                    // Don't select multiple weapons at once.
                    return;
                }
            }
            float dx = touch.x - this.x;
            float dy = touch.y - this.y;
            if (dx * dx + dy * dy < weaponRadius * weaponRadius) {
                if (this.state == WEAPONSTATE_INACTIVE) {
                    this.stateChange(WEAPONSTATE_INACTIVE_HELD);
                } else {
                    // Don't let touches move someone else's tool.
                    if (touch.workspace != this.workspace) {
                        return;
                    }
                    this.stateChange(WEAPONSTATE_ACTIVE_IN_USE);
                }
                this.weaponStore = null;
                this.x = touch.x;
                this.y = touch.y;
                this.holdingTouch = touch;
            }
        }
    }

    void touchUp(FilteredTouch touch) {
        if (this.workspace != null && this.workspace.pointInWorkspace(touch.x, touch.y)) {
            this.lastWorkspaceX = touch.x;
            this.lastWorkspaceY = touch.y;
        }
        if (touch == this.holdingTouch && this.state == WEAPONSTATE_ACTIVE_IN_USE) {
            if (this.workspace.pointInWorkspace(this.x, this.y)) {
                this.stateChange(WEAPONSTATE_ACTIVE);
                this.holdingTouch = null;
                this.activate();
            } else {
                for (Workspace workspace: workspaces) {
                    if (workspace.pointInWorkspace(this.x, this.y)) {
                        // You can't move a weapon onto someone else's workspace, dummy!
                        this.move(this.lastX, this.lastY);
                        this.stateChange(WEAPONSTATE_ACTIVE);
                        this.holdingTouch = null;
                        this.activate();
                        return;
                    }
                }
                this.workspace.setWeapon(null);
                this.workspace = null;
                this.stateChange(WEAPONSTATE_INACTIVE);
                this.placeInWeaponStore();
                this.deactivate();
            }
        } else if (touch == this.holdingTouch && this.state == WEAPONSTATE_INACTIVE_HELD) {
            this.holdingTouch = null;
            for (Workspace workspace: workspaces) {
                if (workspace.pointInWorkspace(this.x, this.y)) {
                    if (workspace.weapon != null) {
                        if (workspace.weapon.state == WEAPONSTATE_ACTIVE_IN_USE) {
                            this.stateChange(WEAPONSTATE_INACTIVE);
                            this.placeInWeaponStore();
                            this.deactivate();
                            return;
                        }
                        workspace.weapon.workspace = null;
                        workspace.weapon.stateChange(WEAPONSTATE_INACTIVE);
                        workspace.weapon.placeInWeaponStore();
                        workspace.weapon.deactivate();
                    }
                    this.weaponStore = null;
                    this.workspace = workspace;
                    workspace.setWeapon(this);
                    this.stateChange(WEAPONSTATE_ACTIVE);
                    this.activate();
                    return;
                }
            }
            // No workspace can hold this weapon, so reset its position.
            if (this.workspace != null) {
                this.workspace.setWeapon(null);
                this.workspace = null;
            }
            this.stateChange(WEAPONSTATE_INACTIVE);
            this.placeInWeaponStore();
            this.deactivate();
        }
    }

    void touchMove(FilteredTouch touch) {
    }

    void touchSignificantMove(FilteredTouch touch) {
        if ((this.state == WEAPONSTATE_INACTIVE_HELD || this.state == WEAPONSTATE_ACTIVE_IN_USE)
                && touch == this.holdingTouch) {
            this.move(touch.x, touch.y);
        }
    }

    /**
     * Log that this weapon attempted to kill an enemy and failed.
     *
     * @param touchMaybe the touch that triggered the enemy-killing procedure
     * for this weapon, or null if it was caused by a spawned cursor
     */
    void miss(FilteredTouch touchMaybe) {
        logEvent(new HybridEnemyMissedEvent(this.workspace.participantIdentifier,
                    touchMaybe == null ? "CursorTap" : "Finger",
                    touchMaybe == null ? 0 : touchMaybe.id,
                    this.x,
                    this.y,
                    "Enemy." + this.weaponType()));
    }

    void activate() {}
    void deactivate() {}

    void placeInWeaponStore() {
        assert(this.weaponStore == null);
        PVector weaponStore = null;
        for (PVector potentialStore: weaponStores) {
            boolean inUse = false;
            for (Weapon weapon: weapons) {
                if (weapon.weaponStore == potentialStore) {
                    // Ignore potential weapon stores that are already in use by
                    // a weapon.
                    inUse = true;
                    break;
                }
            }
            if (inUse) {
                continue;
            }
            if (weaponStore == null) {
                weaponStore = potentialStore;
            } else {
                float dx1 = this.x - weaponStore.x;
                float dy1 = this.y - weaponStore.y;
                float dx2 = this.x - potentialStore.x;
                float dy2 = this.y - potentialStore.y;
                if (dx2 * dx2 + dy2 * dy2 < dx1 * dx1 + dy1 * dy1) {
                    weaponStore = potentialStore;
                }
            }
        }
        assert(weaponStore != null);
        this.weaponStore = weaponStore;
        this.move(this.weaponStore.x, this.weaponStore.y);
    }
}


/**
 * A weapon that defeats its associated enemies by tapping while the enemy's
 * radius overlaps its radius.
 */
class CannonWeapon extends Weapon {
    public final color COLOR = color(215, 55, 5);
    public CannonWeapon(PVector weaponStore) {
        super(weaponStore);
    }
    
    public color weaponColor() { return COLOR; }
    public String weaponType() { return "Cannon"; }

    public void display() {
        displayWeaponCannon(this.visualX, this.visualY, weaponEllipseSize, this.animationAngle, this.weaponColor(), 1.0);
        super.display();
    }

    void cursorTap(Workspace workspace, float x, float y) {
        if (this.state == WEAPONSTATE_ACTIVE_IN_USE && this.workspace == workspace) {
            this.blast(null);
        } else {
            super.cursorTap(workspace, x, y);
        }
    }

    void touchTap(FilteredTouch touch) {
        float dx = touch.x - this.x;
        float dy = touch.y - this.y;
        float radius = CANNON_WEAPON_BLAST_RADIUS * machineTrialScale;
        if ((this.state == WEAPONSTATE_ACTIVE || this.state == WEAPONSTATE_ACTIVE_IN_USE) && this.workspace == 
                touch.workspace && dx * dx + dy * dy <= radius * radius) {
            this.blast(touch);
        } else {
            super.touchTap(touch);
        }
    }

    void blast(FilteredTouch touchMaybe) {
        boolean killed = false;
        for (Enemy enemy: getEnemies()) {
            if (enemy.needsRemoval()) {
                continue;
            }
            if (!this.weaponType().equals(enemy.enemyType())) {
                continue;
            }
            float dx = enemy.x - this.x;
            float dy = enemy.y - this.y;
            float radius = enemy.radius + CANNON_WEAPON_BLAST_RADIUS * machineTrialScale;
            if (dx * dx + dy * dy <= radius * radius) {
                enemy.kill(this.workspace.participantIdentifier,
                           touchMaybe == null ? "CursorTap" : "TouchTap",
                           touchMaybe == null ? 0 : touchMaybe.id,
                           touchMaybe == null ? this.x : touchMaybe.x,
                           touchMaybe == null ? this.y : touchMaybe.y);
                killed = true;
                if (this.workspace != null) {
                    creditParticipant(this.workspace.participantIdentifier, 
                            this.weaponType(), this.x, this.y,
                            enemy.id, enemy.x, enemy.y,
                            touchMaybe, touchMaybe == null ? "CursorTap" : "FingerTap");
                }
            }
        }
        if (!killed) {
            this.miss(touchMaybe);
        }
        createAnimation(new CannonWeaponUsedAnimation(this.visualX, this.visualY,
                                                      this.weaponColor()));
    }
}


/**
 * A weapon that defeats its associated enemies when the outward-facing half of
 * its radius intersects an enemy's radius.
 */
class ShieldWeapon extends Weapon {

    /**
     * The last participant to touch this weapon. Even if they aren't currently
     * wielding it, they should receive credit for enemies deflected by its
     * positioning.
     */
    public String previousParticipant;

    public final color COLOR = color(65, 255, 5);
    public ShieldWeapon(PVector weaponStore) {
        super(weaponStore);
        this.previousParticipant = null;
    }
    
    public color weaponColor() { return COLOR; }
    public String weaponType() { return "Shield"; }

    public void update() {
        super.update();
        if (this.state == WEAPONSTATE_ACTIVE_IN_USE) {
            for (Enemy enemy: getEnemies()) {
                if (enemy.needsRemoval()) {
                    continue;
                }
                if (!this.weaponType().equals(enemy.enemyType())) {
                    continue;
                }
                float dx = enemy.x - this.x;
                float dy = enemy.y - this.y;
                float radius = enemy.radius + CANNON_WEAPON_BLAST_RADIUS * machineTrialScale;
                float innerRadius = enemy.radius + CANNON_WEAPON_BLAST_RADIUS * machineTrialScale - weaponThickness * 3.0;
                // Only defeat enemies that are within the shield's band.
                if (dx * dx + dy * dy <= radius * radius &&
                    dx * dx + dy * dy >= innerRadius * innerRadius) {
                    float xFromCenter = this.x - machineScreenWidth / 2.0;
                    float yFromCenter = this.y - machineScreenHeight / 2.0;
                    float weaponAngle = (float) Math.atan2(yFromCenter, xFromCenter);
                    float angleToEnemy = (float) Math.atan2(dy, dx);
                    float diff = weaponAngle - angleToEnemy;
                    // Only defeat enemies that are within the shield's arc, modulo 2PI, since
                    // that's the easiest way to deal with wraparound on the circle.
                    if ((diff < SHIELD_WEAPON_ARC / 2.0 && diff > -SHIELD_WEAPON_ARC / 2.0) ||
                        (diff + TWO_PI < SHIELD_WEAPON_ARC / 2.0 && diff + TWO_PI > -SHIELD_WEAPON_ARC / 2.0) ||
                        (diff - TWO_PI < SHIELD_WEAPON_ARC / 2.0 && diff - TWO_PI > -SHIELD_WEAPON_ARC / 2.0)) {
                        if (this.previousParticipant != null) {
                            enemy.kill(this.previousParticipant,
                                       "ShieldCollision", 0, this.x, this.y);
                            creditParticipant(this.previousParticipant, 
                                    this.weaponType(), this.x, this.y,
                                    enemy.id, enemy.x, enemy.y,
                                    // If this weapon is currently being held, give credit to the holding finger.
                                    this.state == WEAPONSTATE_INACTIVE_HELD ||
                                        this.state == WEAPONSTATE_ACTIVE_IN_USE ? this.holdingTouch : null,
                                    // If this weapon is not the currently active weapon for the user who last
                                    // positioned it, record that fact.
                                    this.state == WEAPONSTATE_INACTIVE ? "Inactive" : "Active");
                        }
                    }
                }
            }
        }
    }

    public void display() {
        float vx = this.visualX;
        float vy = this.visualY;

        noFill();
        stroke(this.weaponColor());
        float xFromCenter = vx - machineScreenWidth / 2.0;
        float yFromCenter = vy - machineScreenHeight / 2.0;
        float angle = (float) Math.atan2(yFromCenter, xFromCenter);
        float interpolant = (float) Math.sin(this.animationAngle * 6.0) * 0.5 + 0.5;
        float end = SHIELD_WEAPON_SIDE_ARC_END + SHIELD_WEAPON_SIDE_ARC_END_GAIN * interpolant;
        float plusSize = weaponThickness * 0.5 * interpolant;
        strokeWeight(weaponThickness * (1.0 - 0.5 * interpolant));
        arc(vx, vy, weaponEllipseSize + plusSize, weaponEllipseSize + plusSize,
                angle - SHIELD_WEAPON_ARC / 2.0, angle + SHIELD_WEAPON_ARC / 2.0);
        strokeWeight(weaponThickness * (0.5 + 0.5 * interpolant));
        arc(vx, vy, weaponEllipseSize * 0.8 + plusSize, weaponEllipseSize * 0.8 + plusSize,
                angle - SHIELD_WEAPON_ARC / 2.0, angle + SHIELD_WEAPON_ARC / 2.0);
        strokeWeight(weaponThickness);
        arc(vx, vy, weaponEllipseSize, weaponEllipseSize,
                angle - end,
                angle - SHIELD_WEAPON_SIDE_ARC_BEGIN);
        arc(vx, vy, weaponEllipseSize, weaponEllipseSize,
                angle + SHIELD_WEAPON_SIDE_ARC_BEGIN,
                angle + end);
        strokeWeight(STROKE_WEIGHT);

        super.display();
    }

    protected void stateChange(WeaponState state) {
        super.stateChange(state);
        if (this.workspace != null) {
            this.previousParticipant = this.workspace.participantIdentifier;
        }
    }
}


/**
 * A weapon that defeats its associated enemies whenever it encloses an enemy's
 * centre-point with its trail.
 */
class BlackHoleWeapon extends Weapon {
    public final color COLOR = color(15, 105, 255);
    public float tailX[];
    public float tailY[];
    public int tailCursor;
    public BlackHoleWeapon(PVector weaponStore) {
        super(weaponStore);
        this.tailX = new float[BLACKHOLE_WEAPON_TAIL_SIZE];
        this.tailY = new float[BLACKHOLE_WEAPON_TAIL_SIZE];
        for (int i = 0; i < this.tailX.length; ++i) {
            this.tailX[i] = this.x;
            this.tailY[i] = this.y;
        }
    }

    public color weaponColor() { return COLOR; }
    public String weaponType() { return "BlackHole"; }

    public void display() {
        float vx = this.visualX;
        float vy = this.visualY;

        noFill();

        if (this.state == WEAPONSTATE_ACTIVE_IN_USE) {
            stroke(this.weaponColor());
            int end = this.tailCursor - 1;
            if (end == -1) { end = this.tailX.length - 1; }
            for (int i = (this.tailCursor + 1) % this.tailX.length;
                    i != end;
                    i = (i + 1) % this.tailX.length) {
                int next = (i + 1) % this.tailX.length;
                line(this.tailX[i], this.tailY[i], this.tailX[next], this.tailY[next]);
            }
        }

        stroke(this.weaponColor());
        for (float angle = 0.0; angle < TWO_PI - 0.1; angle += TWO_PI / 3.0) {
            strokeWeight(weaponThickness * 0.7);
            arc(vx, vy, weaponEllipseSize, weaponEllipseSize,
                    this.animationAngle + angle - BLACKHOLE_WEAPON_ARC / 2.0,
                    this.animationAngle + angle + BLACKHOLE_WEAPON_ARC / 2.0);
            strokeWeight(weaponThickness * 0.5);
            arc(vx, vy, weaponEllipseSize * 0.8, weaponEllipseSize * 0.8,
                    this.animationAngle + angle + BLACKHOLE_WEAPON_ARC_INNER_OFFSET - BLACKHOLE_WEAPON_ARC / 2.0,
                    this.animationAngle + angle + BLACKHOLE_WEAPON_ARC_INNER_OFFSET + BLACKHOLE_WEAPON_ARC / 2.0);
            strokeWeight(weaponThickness * 0.25);
            arc(vx, vy, weaponEllipseSize * 0.7, weaponEllipseSize * 0.7,
                    this.animationAngle + angle + BLACKHOLE_WEAPON_ARC_INNER_OFFSET * 2.0 - BLACKHOLE_WEAPON_ARC / 2.0,
                    this.animationAngle + angle + BLACKHOLE_WEAPON_ARC_INNER_OFFSET * 2.0 + BLACKHOLE_WEAPON_ARC / 2.0);
            arc(vx, vy, weaponEllipseSize * 0.63, weaponEllipseSize * 0.63,
                    this.animationAngle + angle + BLACKHOLE_WEAPON_ARC_INNER_OFFSET * 3.0 - BLACKHOLE_WEAPON_ARC / 2.0,
                    this.animationAngle + angle + BLACKHOLE_WEAPON_ARC_INNER_OFFSET * 3.0 + BLACKHOLE_WEAPON_ARC / 2.0);
        }
        strokeWeight(STROKE_WEIGHT);

        super.display();
    }

    public void update() {
        super.update();
        int previous = (this.tailCursor + this.tailX.length - 1) % this.tailX.length;
        if (Math.abs(this.tailX[previous] - this.x) > 0.01 || Math.abs(this.tailY[previous] - this.y) > 0.01) {
            this.tailX[this.tailCursor] = this.x;
            this.tailY[this.tailCursor] = this.y;
            this.tailCursor = (this.tailCursor + 1) % this.tailX.length;
        }
        // This is the previous point.
        float ax1 = this.tailX[(this.tailCursor + this.tailX.length - 2) % this.tailX.length];
        float ay1 = this.tailY[(this.tailCursor + this.tailX.length - 2) % this.tailX.length];
        // Since we just incremented the tailCursor, this is the point we just added.
        float ax2 = this.tailX[(this.tailCursor + this.tailX.length - 1) % this.tailX.length];
        float ay2 = this.tailY[(this.tailCursor + this.tailX.length - 1) % this.tailX.length];
        if (this.state != WEAPONSTATE_ACTIVE_IN_USE) {
            return;
        }
        // We're in use, so check to see if an enemy has been caught.
        // Start from -3 and continue to 0, because line segments that share
        // endpoints will always intersect.
        for (int i = (this.tailCursor + this.tailX.length - 3) % this.tailX.length;
             i != this.tailCursor;
             i = (i + this.tailX.length - 1) % this.tailX.length) {
            float bx1 = this.tailX[(i + this.tailX.length - 1) % this.tailX.length];
            float by1 = this.tailY[(i + this.tailX.length - 1) % this.tailX.length];
            float bx2 = this.tailX[(i + this.tailX.length - 0) % this.tailX.length];
            float by2 = this.tailY[(i + this.tailX.length - 0) % this.tailX.length];
            // float t = (q - p) cross s / (r cross s);
            // float u = (p - q) cross r / (s cross r);
            float rx = ax2 - ax1;
            float ry = ay2 - ay1;
            float sx = bx2 - bx1;
            float sy = by2 - by1;
            float r_cross_s = rx * sy - ry * sx;
            float s_cross_r = sx * ry - sy * rx;
            if (Math.abs(r_cross_s) < 0.01 || Math.abs(s_cross_r) < 0.01) {
                // For convenience, we'll ignore the case where both lines are
                // basically parallel. It's rare enough.
                continue;
            }
            float qx_minus_px = bx1 - ax1;
            float qy_minus_py = by1 - ay1;
            float px_minus_qx = ax1 - bx1;
            float py_minus_qy = ay1 - by1;
            float q_minus_p_cross_s = qx_minus_px * sy - qy_minus_py * sx;
            float p_minus_q_cross_r = px_minus_qx * ry - py_minus_qy * rx;
            float t = q_minus_p_cross_s / r_cross_s;
            float u = p_minus_q_cross_r / s_cross_r;
            if (0 <= t && t <= 1 && 0 <= u && u <= 1) {
                // We found an intersection between the most recently added line
                // segment and the line segment at the current index.
                // Check to see if there are any enemies within the loop formed
                // by these line segments.
                //
                // We will use the winding number algorithm, that is:
                // int wn = 0;
                // for (edge) {
                //   if (edge crosses upward) {
                //     if (point is strictly left of edge) wn += 1;
                //   } else if (edge crosses downward) {
                //     if (point is strictly right of edge) wn -= 1;
                //   }
                // }
                //
                // A winding number of zero indicates that the edges of the
                // polygon wind around the point zero times, i.e., the point
                // is not in the polygon.
                boolean killed = false;
                for (Enemy enemy: getEnemies()) {
                    if (enemy.needsRemoval()) {
                        continue;
                    }
                    if (!this.weaponType().equals(enemy.enemyType())) {
                        continue;
                    }
                    // It's important to keep track of both left and right winding numbers, as
                    // otherwise, we can end up "enclosing" something with a complex shape that
                    // intersects itself multiple times when it shouldn't.
                    int leftWindingNumber = 0;
                    int rightWindingNumber = 0;
                    for (int j = (this.tailCursor + this.tailX.length - 3) % this.tailX.length;
                         j != (i + this.tailX.length - 1) % this.tailX.length;
                         j = (j + this.tailX.length - 1) % this.tailX.length) {
                        float ex1 = this.tailX[(j + this.tailX.length - 1) % this.tailX.length];
                        float ey1 = this.tailY[(j + this.tailX.length - 1) % this.tailX.length];
                        float ex2 = this.tailX[(j + this.tailX.length - 0) % this.tailX.length];
                        float ey2 = this.tailY[(j + this.tailX.length - 0) % this.tailX.length];
                        if (ey1 < enemy.y && ey2 >= enemy.y) { // upward crossing
                            float edgeSide = (ex2 - ex1) * (enemy.y - ey1)
                                           - (enemy.x - ex1) * (ey2 - ey1);
                            if (edgeSide > 0) { // enemy is to the left of line segment
                                ++rightWindingNumber;
                            } else {
                                --leftWindingNumber;
                            }
                        } else if (ey2 < enemy.y && ey1 >= enemy.y) { // downward crossing
                            float edgeSide = (ex2 - ex1) * (enemy.y - ey1)
                                           - (enemy.x - ex1) * (ey2 - ey1);
                            if (edgeSide < 0) { // enemy is to the left of inverted line segment
                                --rightWindingNumber;
                            } else {
                                ++leftWindingNumber;
                            }
                        }
                    }
                    if (leftWindingNumber != 0 && rightWindingNumber != 0) {
                        // The shape winds clockwise or counterclockwise around enemy center
                        enemy.kill(this.workspace.participantIdentifier,
                                   this.holdingTouch == null ? "CursorEncircled" : "TouchEncircled",
                                   this.holdingTouch == null ? 0 : this.holdingTouch.id,
                                   this.holdingTouch == null ? this.x : this.holdingTouch.x,
                                   this.holdingTouch == null ? this.y : this.holdingTouch.y);
                        killed = true;
                        if (this.workspace != null) {
                            creditParticipant(this.workspace.participantIdentifier, 
                                    this.weaponType(), this.x, this.y,
                                    enemy.id, enemy.x, enemy.y,
                                    this.holdingTouch,
                                    this.holdingTouch == null ? "CursorEncircled" : "FingerEncircled");
                        }
                    }
                }
                if (!killed) {
                    this.miss(this.holdingTouch);
                }
            }
        }
    }

    public void touchDown(FilteredTouch touch) {
        super.touchDown(touch);
        if (touch == this.holdingTouch) {
            for (int i = 0; i < this.tailX.length; ++i) {
                this.tailX[i] = this.x;
                this.tailY[i] = this.y;
            }
        }
    }

    public void cursorSpawn(Workspace workspace, float x, float y) {
        super.cursorSpawn(workspace, x, y);
        if (workspace == this.workspace && this.state == WEAPONSTATE_ACTIVE_IN_USE) {
            for (int i = 0; i < this.tailX.length; ++i) {
                this.tailX[i] = this.x;
                this.tailY[i] = this.y;
            }
        }
    }

    public void activate() {
        for (int i = 0; i < this.tailX.length; ++i) {
            this.tailX[i] = this.x;
            this.tailY[i] = this.y;
        }
    }
}


/**
 * A weapon whose use is to take a weapon from another player's workspace.
 */
class MagnetWeapon extends Weapon {
    public final color COLOR = color(135, 15, 215);
    public MagnetWeapon(PVector weaponStore) {
        super(weaponStore);
    }

    public color weaponColor() { return COLOR; }
    public String weaponType() { return "Magnet"; }

    public void display() {
        displayWeaponMagnet(this.visualX, this.visualY, weaponEllipseSize, this.animationAngle, this.weaponColor(), 1.0);
        super.display();
    }

    void touchUp(FilteredTouch touch) {
        if (touch == this.holdingTouch && this.state == WEAPONSTATE_ACTIVE_IN_USE && this.workspace != null) {
            for (Workspace workspace: workspaces) {
                if (workspace != this.workspace &&
                        workspace.weapon != null &&
                        workspace.pointInWorkspace(this.x, this.y)) {
                    createAnimation(new MagnetWeaponUsedAnimation(workspace.weapon.x, workspace.weapon.y,
                                                                  this.weaponColor()));
                    playSoundDialog();
                    workspace.weapon.workspace = this.workspace;
                    workspace.weapon.stateChange(WEAPONSTATE_ACTIVE);
                    workspace.weapon.move(this.lastWorkspaceX, this.lastWorkspaceY);
                    workspace.weapon.activate();
                    this.workspace.setWeapon(workspace.weapon);
                    workspace.setWeapon(null);
                    this.workspace = null;
                    this.stateChange(WEAPONSTATE_INACTIVE);
                    this.holdingTouch = null;
                    this.placeInWeaponStore();
                    this.deactivate();
                    return;
                }
            }
        }
        super.touchUp(touch);
    }

    void cursorTap(Workspace cursorWorkspace, float x, float y) {
        if (this.workspace == cursorWorkspace && this.state == WEAPONSTATE_ACTIVE_IN_USE) {
            for (Workspace workspace: workspaces) {
                if (workspace != this.workspace &&
                        workspace.weapon != null &&
                        workspace.pointInWorkspace(this.x, this.y)) {
                    createAnimation(new MagnetWeaponUsedAnimation(workspace.weapon.x, workspace.weapon.y,
                                                                  this.weaponColor()));
                    playSoundDialog();
                    workspace.weapon.workspace = this.workspace;
                    workspace.weapon.stateChange(WEAPONSTATE_ACTIVE_IN_USE);
                    workspace.weapon.move(this.x, this.y);
                    workspace.weapon.activate();
                    this.workspace.setWeapon(workspace.weapon);
                    workspace.setWeapon(null);
                    this.workspace = null;
                    this.stateChange(WEAPONSTATE_INACTIVE);
                    this.holdingTouch = null;
                    this.placeInWeaponStore();
                    this.deactivate();
                    return;
                }
            }
        }
        super.cursorTap(cursorWorkspace, x, y);
    }
}
