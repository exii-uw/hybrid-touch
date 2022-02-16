

float displayOffsetX = 0;
float displayOffsetY = 0;


private final int OFFSCREEN_INDICATOR_BORDER = 64;
private final int OFFSCREEN_INDICATOR_LENGTH = 32;
private final int OFFSCREEN_INDICATOR_WIDTH = 96;


private final float ANIMATION_FADE_RATE = 0.9;
private final float ANIMATION_REMOVE_THRESHOLD = 0.001;
private final int TOUCH_ANIMATION_MAX_SIZE = 128;
private final float TARGET_HIT_ANIMATION_SIZE = 0.8;
private final float TARGET_MISSED_ANIMATION_SIZE = 1.6;
private final float TARGET_SPAWN_ANIMATION_SIZE = 64.0;
private final int TARGET_SPAWN_ANIMATION_BORDER = 32;
private final int TARGET_MOVE_GRADIENT_SEGMENTS = 24;


private final int CURSOR_SIZE_MIN = 16; // How large to draw the cursor point at min distance
private final int CURSOR_SIZE_MAX = 32; // How large to draw the cursor point at max distance
private final int CURSOR_HALO_SIZE = 256; // Maximum size of the halo around the cursor point


private final int DEBUG_RAW_TOUCH_SIZE = 128;
private final int DEBUG_FILTERED_TOUCH_SIZE = 96;
private final int DEBUG_LIFTED_TOUCH_SIZE = 64;
private final int DEBUG_DISPLAY_OFFSET_X = 0;
private final int DEBUG_DISPLAY_OFFSET_Y = 0;


private List<Animation> animations = new ArrayList<Animation>();
private List<Animation> animationsToRemove = new ArrayList<Animation>();
private final int MAXIMUM_ANIMATIONS = 8;


/**
 * Add a new animation to the screen.
 */
void createAnimation(Animation animation) {
    animations.add(animation);
    while (animations.size() > MAXIMUM_ANIMATIONS) {
        float minimumFade = 1.0;
        Animation animationToRemove = null;
        for (Animation otherAnimation: animations) {
            if (otherAnimation.fade < minimumFade) {
                minimumFade = otherAnimation.fade;
                animationToRemove = otherAnimation;
            }
        }
        animations.remove(animationToRemove);
    }
}


/**
 * Show all currently active animations, and update their timers.
 */
void displayAnimations() {
    for (Animation animation: animations) {
        animation.display();
        if (animation.fade < ANIMATION_REMOVE_THRESHOLD) {
            animationsToRemove.add(animation);
        }
    }
    for (Animation animation: animationsToRemove) {
        animations.remove(animation);
    }
    animationsToRemove.clear();
}


/**
 * Show the edges of the screen.
 */
void displayScreenBoundaries(float displayOffsetX, float displayOffsetY) {
    stroke(100, 255);
    fill(0, 0);
    rect(0 + displayOffsetX - 1,
         0 + displayOffsetY - 1,
         machineScreenWidth + 2,
         machineScreenHeight + 2);
}


/**
 * Show the target.
 */
void displayTarget(float targetX, float targetY, float targetWidth, float targetHeight) {
    stroke(0, 0);
    fill(255, 0, 0);
    ellipse(targetX + displayOffsetX, targetY + displayOffsetY, targetWidth, targetHeight);
    displayOffscreenIndicator(targetX + displayOffsetX, targetY + displayOffsetY, 1.2, 255, 0, 0, 255);
}


/**
 * Show where the target will be going.
 */
void displayTargetIndicator(int id, float targetX, float targetY, float targetWidth, float targetHeight) {
    stroke(0, 0);
    fill(32);
    ellipse(targetX + displayOffsetX, targetY + displayOffsetY, targetWidth, targetHeight);
}


/**
 * Show where the participant should stand.
 */
void displayStandingPositionIndicator(float x) {
    stroke(0, 0);
    fill(255, 136, 20, 255);
    rect(x - 32, 0, 64, machineScreenHeight);
}


/**
 * Draw a progress ring.
 */
void displayProgressRing(float x, float y, float r, float progress, float opacity, float ping) {
    float o = opacity / 255.0;
    stroke(127, 127, 127, 255 * o);
    fill(127, 127, 127, 32 * o);
    ellipse(x, y, r, r);
    if (progress < 1.0) {
        stroke(35, 192, 0, 255 * o);
        fill(35, 192, 0, 192 * o);
    } else {
        stroke(35, 255, 0, 255 * o);
        fill(35, 255, 0, 192 * o);
    }
    arc(x, y, r, r, -HALF_PI, -HALF_PI + 2 * PI * progress);
    stroke(192, 192, 192, 255 * o);
    if (progress < 1.0) {
        fill(127, 127, 127, 192 * o);
    } else {
        fill(127, 127, 127, 255 * o);
    }
    ellipse(x, y, r - 32, r - 32);
    textSize(r * 0.4);
    stroke(255, 255 * o);
    fill(255, 128 * o);
    textAlign(CENTER, CENTER);
    text("OK", x - 4, y - 12);
    float pingOpacity = ping * 255;
    float pingRadius = r + (1 - ping) * 256;
    stroke(32, 255, 0, pingOpacity);
    fill(0, 0);
    ellipse(x, y, pingRadius, pingRadius);
}


/**
 * Draw a cursor.
 */
void displayCursor(float cursorX, float cursorY, float cursorDistance) {
    stroke(255, 255);
    fill(255, 128);
    float cursorSize = CURSOR_SIZE_MIN + (CURSOR_SIZE_MAX - CURSOR_SIZE_MIN) * cursorDistance;
    line(cursorX - cursorSize / 2, cursorY, cursorX + cursorSize / 2, cursorY);
    line(cursorX, cursorY - cursorSize / 2, cursorX, cursorY + cursorSize / 2);
    displayOffscreenIndicator(cursorX, cursorY, 1.0, 255, 255, 255, 128);
    stroke(255, 25);
    fill(255, 50);
    ellipse(cursorX,
            cursorY,
            cursorDistance * CURSOR_HALO_SIZE,
            cursorDistance * CURSOR_HALO_SIZE);
}


/**
 * Draw a dead zone.
 */
void displayDebugDeadZone(float zoneX, float zoneY, float zoneRadius, float life) {
    stroke(50, 0);
    fill(50, 255 * life);
    ellipse(zoneX,
            zoneY,
            zoneRadius * 2,
            zoneRadius * 2);
}

/**
 * Draw the border of the screen around which touchDown events are ignored.
 */
void displayDebugIgnoreBorder(int size) {
    stroke(0, 0);
    fill(10, 255);
    rect(0, 0, width, size);
    rect(0, height - size, width, size);
    rect(0, size, size, height - 2 * size);
    rect(width - size, size, size, height - 2 * size);
}


/**
 * Draw a touch as it was received by the input driver.
 */
void displayDebugRawTouch(float touchX, float touchY) {
    stroke(250, 67, 8, 255);
    fill(250, 67, 8, 128);
    ellipse(touchX + DEBUG_DISPLAY_OFFSET_X,
            touchY + DEBUG_DISPLAY_OFFSET_Y,
            DEBUG_RAW_TOUCH_SIZE,
            DEBUG_RAW_TOUCH_SIZE);
    displayOffscreenIndicator(touchX + DEBUG_DISPLAY_OFFSET_X,
                              touchY + DEBUG_DISPLAY_OFFSET_Y,
                              1.0,
                              250, 67, 8, 128);
}


/**
 * Draw a touch that's been filtered by filter.pde.
 */
void displayDebugFilteredTouch(float touchX, float touchY, boolean canTouchTap) {
    stroke(67, 250, 8, canTouchTap ? 255 : 127);
    fill(67, 250, 8, canTouchTap ? 127 : 63);
    ellipse(touchX + DEBUG_DISPLAY_OFFSET_X,
            touchY + DEBUG_DISPLAY_OFFSET_Y,
            DEBUG_FILTERED_TOUCH_SIZE,
            DEBUG_FILTERED_TOUCH_SIZE);
    displayOffscreenIndicator(touchX + DEBUG_DISPLAY_OFFSET_X,
                              touchY + DEBUG_DISPLAY_OFFSET_Y,
                              0.9,
                              67, 250, 8, 128);
}


/**
 * Draw a touch that was recently lifted but is still being tracked by
 * filter.pde.
 */
void displayDebugLiftedTouch(float touchX, float touchY) {
    stroke(8, 67, 250, 255);
    fill(8, 67, 250, 128);
    ellipse(touchX + DEBUG_DISPLAY_OFFSET_X,
            touchY + DEBUG_DISPLAY_OFFSET_Y,
            DEBUG_LIFTED_TOUCH_SIZE,
            DEBUG_LIFTED_TOUCH_SIZE);
    displayOffscreenIndicator(touchX + DEBUG_DISPLAY_OFFSET_X,
                              touchY + DEBUG_DISPLAY_OFFSET_Y,
                              0.8,
                              8, 67, 250, 128);
}


/**
 * Draw an arrow pointing offscreen if the given point is too close to the
 * border of the screen.
 * @param x      the x coordinate of the point
 * @param y      the y coordinate of the point
 * @param s      how much larger than usual to draw the indicator (1.0 for usual)
 * @param r      the red component of the fill colour
 * @param g      the green component of the fill colour
 * @param b      the blue component of the fill colour
 * @param a      the opacity of the fill colour, doubled for the stroke opacity
 */
void displayOffscreenIndicator(float x, float y, float s, float r, float g, float b, float a) {
    if (x < OFFSCREEN_INDICATOR_BORDER || x > machineScreenWidth - OFFSCREEN_INDICATOR_BORDER
     || y < OFFSCREEN_INDICATOR_BORDER || y > machineScreenHeight - OFFSCREEN_INDICATOR_BORDER) {
        // Calculate where the point would be if it were constrained within
        // the screen boundary, including the border.
        float cx = Math.max(OFFSCREEN_INDICATOR_BORDER, Math.min(x, machineScreenWidth - OFFSCREEN_INDICATOR_BORDER));
        float cy = Math.max(OFFSCREEN_INDICATOR_BORDER, Math.min(y, machineScreenHeight - OFFSCREEN_INDICATOR_BORDER));
        PVector direction = new PVector(x - cx, y - cy);
        float opacity = Math.min(1, direction.mag() / OFFSCREEN_INDICATOR_BORDER);
        direction.normalize();
        PVector perpendicular = new PVector(-direction.y, direction.x);
        fill(r, g, b, a * opacity);
        stroke(r, g, b, Math.min(a * 2, 1) * opacity);
        s -= 0.1 * (1 - opacity);
        float x0 = cx + direction.x * OFFSCREEN_INDICATOR_LENGTH * s;
        float y0 = cy + direction.y * OFFSCREEN_INDICATOR_LENGTH * s;
        float x1 = cx + perpendicular.x * OFFSCREEN_INDICATOR_WIDTH / 2 * s;
        float y1 = cy + perpendicular.y * OFFSCREEN_INDICATOR_WIDTH / 2 * s;
        float x2 = cx - perpendicular.x * OFFSCREEN_INDICATOR_WIDTH / 2 * s;
        float y2 = cy - perpendicular.y * OFFSCREEN_INDICATOR_WIDTH / 2 * s;
        triangle(x0, y0, x1, y1, x2, y2);
    }
}


/**
 * Draw the estimated location of the participant.
 */
void displayParticipantLocation(float x, float y) {
    stroke(255, 198, 0, 0);
    fill(255, 198, 0, 32);
    ellipse(x, y, 320, 320);
    stroke(255, 198, 0, 255);
    fill(255, 198, 0, 128);
    ellipse(x, y, 40, 40);
    line(x - 20, y, x + 20, y);
    line(x, y - 20, x, y + 20);
}


class Animation {
    float x;
    float y;
    float fade;
    Animation(float x, float y) {
        this.x = x;
        this.y = y;
        this.fade = 1.0;
    }
    void display() {
        this.fade *= ANIMATION_FADE_RATE;
    }
}


class ClickAnimation extends Animation {
    ClickAnimation(float x, float y) {
        super(x, y);
    }
    void display() {
        float size = TOUCH_ANIMATION_MAX_SIZE * (1 - this.fade);
        fill(255, 64 * this.fade);
        stroke(255, 192 * this.fade);
        ellipse(this.x, this.y, (int) size, (int) size);
        super.display();
    }
}


class TargetHitAnimation extends Animation {
    float width;
    float height;
    TargetHitAnimation(float x, float y, float width, float height) {
        super(x, y);
        this.width = width;
        this.height = height;
    }
    void display() {
        float t = this.fade * (1 - TARGET_HIT_ANIMATION_SIZE) + TARGET_HIT_ANIMATION_SIZE;
        float width = this.width * t;
        float height = this.height * t;
        fill(255, 255 * this.fade);
        stroke(0, 0);
        ellipse(this.x + displayOffsetX, this.y + displayOffsetY, width, height);
        super.display();
    }
}


class TargetMissedAnimation extends Animation {
    float width;
    float height;
    TargetMissedAnimation(float x, float y, float width, float height) {
        super(x, y);
        this.width = width;
        this.height = height;
    }
    void display() {
        float t = this.fade * (1 - TARGET_MISSED_ANIMATION_SIZE) + TARGET_MISSED_ANIMATION_SIZE;
        float width = this.width * t;
        float height = this.height * t;
        fill(255, 0, 0, 255 * this.fade);
        stroke(0, 0);
        ellipse(this.x + displayOffsetX, this.y + displayOffsetY, width, height);
        super.display();
    }
}


class TargetSpawnAnimation extends Animation {
    float width;
    float height;
    TargetSpawnAnimation(float x, float y, float width, float height) {
        super(x, y);
        this.width = width;
        this.height = height;
    }
    void display() {
        float opacity;
        if (fade < 0.5) {
            opacity = fade / 0.5;
        } else {
            opacity = (1 - fade) / 0.5;
        }
        fill(0, 0);
        float width = this.width + this.fade * TARGET_SPAWN_ANIMATION_SIZE;
        float height = this.height + this.fade * TARGET_SPAWN_ANIMATION_SIZE;
        stroke(255, 255 * this.fade, 255 * this.fade, 255 * opacity);
        ellipse(this.x + displayOffsetX,
                this.y + displayOffsetY,
                width + TARGET_SPAWN_ANIMATION_BORDER * 2,
                height + TARGET_SPAWN_ANIMATION_BORDER * 2);
        stroke(128, 128 * this.fade, 128 * this.fade, 255 * opacity);
        ellipse(this.x + displayOffsetX,
                this.y + displayOffsetY,
                width + TARGET_SPAWN_ANIMATION_BORDER * 2 + 4,
                height + TARGET_SPAWN_ANIMATION_BORDER * 2 + 4);
        ellipse(this.x + displayOffsetX,
                this.y + displayOffsetY,
                width + TARGET_SPAWN_ANIMATION_BORDER * 2 - 4,
                height + TARGET_SPAWN_ANIMATION_BORDER * 2 - 4);
        super.display();
    }
}


class TargetMoveAnimation extends Animation {
    float nx;
    float ny;
    TargetMoveAnimation(float x, float y, float nx, float ny) {
        super(x, y);
        this.nx = nx;
        this.ny = ny;
    }
    void display() {
        for (int i = 0; i < TARGET_MOVE_GRADIENT_SEGMENTS; ++i) {
            float n = (float) TARGET_MOVE_GRADIENT_SEGMENTS;
            float x0 = (i / n) * this.x + (1 - i / n) * this.nx + displayOffsetX;
            float y0 = (i / n) * this.y + (1 - i / n) * this.ny + displayOffsetY;
            float x1 = ((i + 1) / n) * this.x + (1 - (i + 1) / n) * this.nx + displayOffsetX;
            float y1 = ((i + 1) / n) * this.y + (1 - (i + 1) / n) * this.ny + displayOffsetY;
            stroke(255, 255 * (float) Math.pow(this.fade, 1 + 2 * (i / n)));
            line(x0, y0, x1, y1);
        }
        super.display();
    }
}


class TargetIndicatorMoveAnimation extends Animation {
    int id;
    float nx;
    float ny;
    TargetIndicatorMoveAnimation(int id, float x, float y, float nx, float ny) {
        super(x, y);
        this.id = id;
        this.nx = nx;
        this.ny = ny;
    }
    void display() {
        /*
        for (int i = 0; i < TARGET_MOVE_GRADIENT_SEGMENTS; ++i) {
            float n = (float) TARGET_MOVE_GRADIENT_SEGMENTS;
            float x0 = (i / n) * this.x + (1 - i / n) * this.nx + displayOffsetX;
            float y0 = (i / n) * this.y + (1 - i / n) * this.ny + displayOffsetY;
            float x1 = ((i + 1) / n) * this.x + (1 - (i + 1) / n) * this.nx + displayOffsetX;
            float y1 = ((i + 1) / n) * this.y + (1 - (i + 1) / n) * this.ny + displayOffsetY;
            stroke(255, 255 * ((float) (3 - id)) / 3.0 * (float) Math.pow(this.fade, 1 + 2 * (i / n)));
            line(x0, y0, x1, y1);
        }
        */
        super.display();
    }
}


class StandingPositionIndicatorSpawnAnimation extends Animation {
    StandingPositionIndicatorSpawnAnimation(float x) {
        super(x, 0);
    }
    void display() {
        float size = 256 + 256 * this.fade;
        stroke(0, 0);
        fill(255, 136, 20, 127 * this.fade);
        rect(x - size / 2, 0, size, machineScreenHeight);
        super.display();
    }
}


class StandingPositionIndicatorDespawnAnimation extends Animation {
    StandingPositionIndicatorDespawnAnimation(float x) {
        super(x, 0);
    }
    void display() {
        float opacity = (float) Math.pow(this.fade, 2.0);
        float size = 64 * this.fade;
        stroke(0, 0);
        fill(255, 136, 20, 255 * opacity);
        rect(x - size / 2, 0, size, machineScreenHeight);
        super.display();
    }
}

