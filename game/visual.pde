

float displayOffsetX = 0;
float displayOffsetY = 0;


private final int STROKE_WEIGHT = 2;


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
        float minimumFade = 65536.0;
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
    float cursorSize = CURSOR_SIZE_MIN + (CURSOR_SIZE_MAX - CURSOR_SIZE_MIN) * cursorDistance;
    strokeWeight(STROKE_WEIGHT * 3.0);
    stroke(0, 255);
    line(cursorX - cursorSize / 2, cursorY, cursorX + cursorSize / 2, cursorY);
    line(cursorX, cursorY - cursorSize / 2, cursorX, cursorY + cursorSize / 2);
    strokeWeight(STROKE_WEIGHT);
    stroke(255, 255);
    line(cursorX - cursorSize / 2, cursorY, cursorX + cursorSize / 2, cursorY);
    line(cursorX, cursorY - cursorSize / 2, cursorX, cursorY + cursorSize / 2);
    displayOffscreenIndicator(cursorX, cursorY, 1.0, 255, 255, 255, 128);
    stroke(0, 50);
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


/**
 * Display the cannon weapon.
 */
void displayWeaponCannon(float x, float y,
                         float weaponEllipseSize,
                         float animationAngle,
                         color weaponColor,
                         float fade) {
    noFill();
    stroke(weaponColor);
    for (float angle = 0.0; angle < TWO_PI - 0.1; angle += TWO_PI / 4.0) {
        strokeWeight(weaponThickness * fade);
        arc(x, y, weaponEllipseSize, weaponEllipseSize,
                animationAngle + angle - CANNON_WEAPON_ARC / 2.0,
                animationAngle + angle + CANNON_WEAPON_ARC / 2.0);
        strokeWeight(weaponThickness * 0.5 * fade);
        arc(x, y, weaponEllipseSize * 0.8, weaponEllipseSize * 0.8,
                animationAngle + angle - CANNON_WEAPON_ARC_INNER / 2.0,
                animationAngle + angle + CANNON_WEAPON_ARC_INNER / 2.0);
    }
    strokeWeight(STROKE_WEIGHT);
}


/**
 * Display the magnet weapon.
 */
void displayWeaponMagnet(float x, float y,
                         float weaponEllipseSize,
                         float animationAngle,
                         color weaponColor,
                         float fade) {
    noFill();
    stroke(weaponColor);
    for (float angle = 0.0; angle < TWO_PI - 0.1; angle += TWO_PI / 2.0) {
        strokeWeight(weaponThickness * fade);
        arc(x, y, weaponEllipseSize, weaponEllipseSize,
                animationAngle + angle - MAGNET_WEAPON_ARC / 2.0,
                animationAngle + angle + MAGNET_WEAPON_ARC / 2.0);
        strokeWeight(weaponThickness * 0.5 * fade);
        arc(x, y, weaponEllipseSize * 0.8, weaponEllipseSize * 0.8,
                animationAngle + angle - MAGNET_WEAPON_ARC / 2.0,
                animationAngle + angle + MAGNET_WEAPON_ARC / 2.0);
        strokeWeight(weaponThickness * fade);
        arc(x, y, weaponEllipseSize, weaponEllipseSize,
                animationAngle + angle - MAGNET_WEAPON_ARC / 2.0 - MAGNET_WEAPON_SIDE_ARC_ADD_END
                    - MAGNET_WEAPON_SIDE_ARC_ADD_END - MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN,
                animationAngle + angle - MAGNET_WEAPON_ARC / 2.0 - MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN
                    - MAGNET_WEAPON_SIDE_ARC_ADD_END - MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN);
        arc(x, y, weaponEllipseSize, weaponEllipseSize,
                animationAngle + angle - MAGNET_WEAPON_ARC / 2.0 - MAGNET_WEAPON_SIDE_ARC_ADD_END,
                animationAngle + angle - MAGNET_WEAPON_ARC / 2.0 - MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN);
        arc(x, y, weaponEllipseSize, weaponEllipseSize,
                animationAngle + angle + MAGNET_WEAPON_ARC / 2.0 + MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN,
                animationAngle + angle + MAGNET_WEAPON_ARC / 2.0 + MAGNET_WEAPON_SIDE_ARC_ADD_END);
        arc(x, y, weaponEllipseSize, weaponEllipseSize,
                animationAngle + angle + MAGNET_WEAPON_ARC / 2.0 + MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN
                    + MAGNET_WEAPON_SIDE_ARC_ADD_END + MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN,
                animationAngle + angle + MAGNET_WEAPON_ARC / 2.0 + MAGNET_WEAPON_SIDE_ARC_ADD_END
                    + MAGNET_WEAPON_SIDE_ARC_ADD_END + MAGNET_WEAPON_SIDE_ARC_ADD_BEGIN);
    }
    strokeWeight(STROKE_WEIGHT);
}


/**
 * Display the container where active weapons are stored.
 */
void displayWeaponStore(float x, float y) {
    stroke(50);
    fill(50, 127);
    ellipse(x, y, WEAPON_RADIUS * 2.0 + 16.0, WEAPON_RADIUS * 2.0 + 16.0);
}


/**
 * Display a participant's score centered in the given rectangle.
 */
void displayParticipantScore(int participantScore, float x, float y, float width, float height) {
    textFont(workspaceParticipantIdentifierFont, 96);
    textAlign(CENTER);
    fill(0);
    text(new Integer(participantScore).toString(), x + 4.0, y + 4.0, width, height);
    fill(255);
    text(new Integer(participantScore).toString(), x, y, width, height);
}


/**
 * Display a score for all participants combined.
 */
void displaySummedScore(int summedScore) {
    displayParticipantScore(summedScore,
            machineScreenWidth / 2.0,
            machineScreenHeight / 2.0 - WORKSPACE_TEXT_GUTTER,
            earthRadius,
            WORKSPACE_TEXT_GUTTER * 2.0);
    displayParticipantScore(summedScore,
            machineScreenWidth / 2.0 - earthRadius,
            machineScreenHeight / 2.0 - WORKSPACE_TEXT_GUTTER,
            earthRadius,
            WORKSPACE_TEXT_GUTTER * 2.0);
}


/**
 * Display the current wave of enemies.
 */
void displayWaveCount(int currentWave) {
    textFont(workspaceParticipantIdentifierFont, 48);
    float x = machineScreenWidth / 2.0 - WORKSPACE_MID_GUTTER / 2.0;
    float y = WORKSPACE_TEXT_GUTTER;
    float width = WORKSPACE_MID_GUTTER / 2.0;
    float height = 96;
    textAlign(CENTER);
    fill(0);
    text("WAVE", x + 4.0, y + 4.0, width, height);
    fill(255);
    text("WAVE", x, y, width, height);

    textSize(96);
    x = machineScreenWidth / 2.0;
    textAlign(CENTER);
    fill(0);
    text(new Integer(currentWave).toString(), x + 4.0, y + 4.0, width, height);
    fill(255);
    text(new Integer(currentWave).toString(), x, y, width, height);
}


/**
 * Display a workspace that covers either the left or the right half of the screen.
 */
void displayHalfscreenWorkspace(boolean isRightHalf,
                                color participantColor, String participantIdentifier,
                                int participantScore,
                                String weaponType, color weaponColor) {
    stroke(participantColor);
    noFill();
    textFont(workspaceParticipantIdentifierFont, 96);
    if (!isRightHalf) { // Left
        rect(WORKSPACE_EDGE_GUTTER, WORKSPACE_EDGE_GUTTER,
                machineScreenWidth / 2.0 - WORKSPACE_EDGE_GUTTER * 2.0 - WORKSPACE_MID_GUTTER / 2.0,
                machineScreenHeight - WORKSPACE_EDGE_GUTTER * 2.0,
                WORKSPACE_ROUNDED_CORNER_RADIUS);
        if (weaponType != null) {
            stroke(weaponColor);
            rect(WORKSPACE_EDGE_GUTTER + WORKSPACE_WEAPON_EDGE_GUTTER,
                 WORKSPACE_EDGE_GUTTER + WORKSPACE_WEAPON_EDGE_GUTTER,
                 machineScreenWidth / 2.0 - WORKSPACE_EDGE_GUTTER * 2.0 - WORKSPACE_MID_GUTTER / 2.0
                    - WORKSPACE_WEAPON_EDGE_GUTTER * 2.0,
                 machineScreenHeight - WORKSPACE_EDGE_GUTTER * 2.0
                    - WORKSPACE_WEAPON_EDGE_GUTTER * 2.0,
                    WORKSPACE_ROUNDED_CORNER_RADIUS - WORKSPACE_WEAPON_EDGE_GUTTER);
            textAlign(RIGHT);
            fill(weaponColor);
            text(weaponType, WORKSPACE_TEXT_GUTTER, WORKSPACE_TEXT_GUTTER,
                    machineScreenWidth / 2.0 - WORKSPACE_MID_GUTTER / 2.0 - WORKSPACE_TEXT_GUTTER * 2.0,
                    machineScreenHeight - WORKSPACE_TEXT_GUTTER * 2.0);
        }
        textAlign(LEFT);
        fill(participantColor);
        text(participantIdentifier, WORKSPACE_TEXT_GUTTER, WORKSPACE_TEXT_GUTTER,
                machineScreenWidth / 2.0 - WORKSPACE_MID_GUTTER / 2.0 - WORKSPACE_TEXT_GUTTER * 2.0,
                machineScreenHeight - WORKSPACE_TEXT_GUTTER * 2.0);
        if (!CONFIG_COOPERATIVE_MODE) {
            displayParticipantScore(participantScore,
                    machineScreenWidth / 4.0,
                    WORKSPACE_TEXT_GUTTER,
                    machineScreenWidth / 4.0 - WORKSPACE_MID_GUTTER / 2.0 - WORKSPACE_TEXT_GUTTER * 2.0,
                    machineScreenHeight - WORKSPACE_TEXT_GUTTER * 2.0);
        }
    } else { // Right
        rect(machineScreenWidth / 2.0 + WORKSPACE_EDGE_GUTTER + WORKSPACE_MID_GUTTER / 2.0, WORKSPACE_EDGE_GUTTER,
                machineScreenWidth / 2.0 - WORKSPACE_EDGE_GUTTER * 2.0 - WORKSPACE_MID_GUTTER / 2.0,
                machineScreenHeight - WORKSPACE_EDGE_GUTTER * 2.0,
                WORKSPACE_ROUNDED_CORNER_RADIUS);
        if (weaponType != null) {
            stroke(weaponColor);
            rect(machineScreenWidth / 2.0 + WORKSPACE_EDGE_GUTTER + WORKSPACE_MID_GUTTER / 2.0
                    + WORKSPACE_WEAPON_EDGE_GUTTER,
                 WORKSPACE_EDGE_GUTTER + WORKSPACE_WEAPON_EDGE_GUTTER,
                 machineScreenWidth  / 2.0 - WORKSPACE_EDGE_GUTTER * 2.0 - WORKSPACE_MID_GUTTER / 2.0
                    - WORKSPACE_WEAPON_EDGE_GUTTER * 2.0,
                 machineScreenHeight - WORKSPACE_EDGE_GUTTER * 2.0
                    - WORKSPACE_WEAPON_EDGE_GUTTER * 2.0,
                    WORKSPACE_ROUNDED_CORNER_RADIUS - WORKSPACE_WEAPON_EDGE_GUTTER);
            textAlign(LEFT);
            fill(weaponColor);
            text(weaponType,
                    machineScreenWidth / 2.0 + WORKSPACE_MID_GUTTER / 2.0 + WORKSPACE_TEXT_GUTTER,
                    WORKSPACE_TEXT_GUTTER,
                    machineScreenWidth / 2.0 - WORKSPACE_MID_GUTTER / 2.0 - WORKSPACE_TEXT_GUTTER * 2.0,
                    machineScreenHeight - WORKSPACE_TEXT_GUTTER * 2.0);
        }
        textAlign(RIGHT);
        fill(participantColor);
        text(participantIdentifier,
                machineScreenWidth / 2.0 + WORKSPACE_MID_GUTTER / 2.0 + WORKSPACE_TEXT_GUTTER,
                WORKSPACE_TEXT_GUTTER,
                machineScreenWidth / 2.0 - WORKSPACE_MID_GUTTER / 2.0 - WORKSPACE_TEXT_GUTTER * 2.0,
                machineScreenHeight - WORKSPACE_TEXT_GUTTER * 2.0);
        if (!CONFIG_COOPERATIVE_MODE) {
            displayParticipantScore(participantScore,
                    machineScreenWidth / 2.0 + WORKSPACE_MID_GUTTER / 2.0 + WORKSPACE_TEXT_GUTTER,
                    WORKSPACE_TEXT_GUTTER,
                    machineScreenWidth / 4.0 - WORKSPACE_MID_GUTTER / 2.0 - WORKSPACE_TEXT_GUTTER,
                    machineScreenHeight - WORKSPACE_TEXT_GUTTER * 2.0);
        }
    }
}


/**
 * Display a workspace that can be picked up and moved.
 */
void displayMobileWorkspace(float x, float y, boolean isCurrentlyHeld,
                            color participantColor, String participantIdentifier,
                            int participantScore,
                            String weaponType, color weaponColor) {
    float diameter = WORKSPACE_MOVABLE_RADIUS * 2.0;
    stroke(participantColor);
    noFill();
    textFont(workspaceParticipantIdentifierFont, 96);
    ellipse(x, y, diameter, diameter);
    textAlign(CENTER);
    if (weaponType != null) {
        stroke(weaponColor);
        ellipse(x, y, diameter - WORKSPACE_WEAPON_EDGE_GUTTER, diameter - WORKSPACE_WEAPON_EDGE_GUTTER);
        fill(weaponColor);
        text(weaponType,
                x - WORKSPACE_MOVABLE_RADIUS + WORKSPACE_TEXT_GUTTER,
                y + WORKSPACE_MOVABLE_RADIUS - WORKSPACE_TEXT_GUTTER - 96,
                diameter - WORKSPACE_TEXT_GUTTER * 2.0, 96);
    }
    fill(participantColor);
    text(participantIdentifier,
            x - WORKSPACE_MOVABLE_RADIUS + WORKSPACE_TEXT_GUTTER,
            y - WORKSPACE_MOVABLE_RADIUS + WORKSPACE_TEXT_GUTTER,
            diameter - WORKSPACE_TEXT_GUTTER * 2.0, 96);
    if (!CONFIG_COOPERATIVE_MODE) {
        displayParticipantScore(participantScore,
            x - WORKSPACE_MOVABLE_RADIUS + WORKSPACE_TEXT_GUTTER,
            y - WORKSPACE_MOVABLE_RADIUS + WORKSPACE_TEXT_GUTTER + 96,
            diameter - WORKSPACE_TEXT_GUTTER * 2.0, 96);
    }
    stroke(96);
    fill(isCurrentlyHeld ? 32 : 64);
    ellipse(x + WORKSPACE_MOVABLE_HANDLE_POSITION_X,
            y + WORKSPACE_MOVABLE_HANDLE_POSITION_Y,
            WORKSPACE_MOVABLE_HANDLE_RADIUS * 2.0, WORKSPACE_MOVABLE_HANDLE_RADIUS * 2.0);
}


void displayClippedArc(float x, float y, float w, float h, float a1, float a2, float l1, float l2) {
    while (l2 < l1) {
        l2 += TWO_PI;
    }
    while (a2 < a1) {
        a2 += TWO_PI;
    }
    while (a1 >= 3.0 * PI / 2.0) {
        a1 -= TWO_PI;
        a2 -= TWO_PI;
    }
    while (a2 < -PI / 2.0) {
        a1 += TWO_PI;
        a2 += TWO_PI;
    }
    while (l1 >= 3.0 * PI / 2.0) {
        l1 -= TWO_PI;
        l2 -= TWO_PI;
    }
    while (l2 < -PI / 2.0) {
        l1 += TWO_PI;
        l2 += TWO_PI;
    }
    // Processing doesn't seem to like negative values so bring it into the range [7pi/2, 11pi/2).
    a1 += 2 * TWO_PI;
    a2 += 2 * TWO_PI;
    l1 += 2 * TWO_PI;
    l2 += 2 * TWO_PI;
    float b1 = a1 < l1 ? l1 : a1 > l2 ? l2 : a1; // Clamp to value between l1 and l2
    float b2 = a2 < l1 ? l1 : a2 > l2 ? l2 : a2;
    arc(x, y, w, h, b1, b2);
    a1 -= TWO_PI;
    a2 -= TWO_PI;
    float c1 = a1 < l1 ? l1 : a1 > l2 ? l2 : a1; // Clamp to value between l1 and l2
    float c2 = a2 < l1 ? l1 : a2 > l2 ? l2 : a2;
    arc(x, y, w, h, c1, c2);
}


/**
 * Display the earth across a given angle range (whose endpoints should be within the range
 * [-pi/2, 3pi/2).)
 */
void displayEarth(float x, float y, float earthRadius, float healthRatio, float angle,
        float minAngle, float maxAngle) {
    float earthColorR = 164 + healthRatio * ( 81 - 164);
    float earthColorG = 122 + healthRatio * (224 - 122);
    float earthColorB =  56 + healthRatio * (  3 -  56);
    noFill();
    stroke(earthColorR, earthColorG, earthColorB);
    strokeWeight(16);
    if (maxAngle - minAngle > TWO_PI * 0.99) {
        arc(x, y, earthRadius * 2 + 32, earthRadius * 2 + 32,
                (1.0 - healthRatio) * TWO_PI + PI + HALF_PI, TWO_PI + PI + HALF_PI);
    } else if (minAngle < 0.0) {
        arc(x, y, earthRadius * 2 + 32, earthRadius * 2 + 32,
                minAngle + (1.0 - healthRatio) * (maxAngle - minAngle), maxAngle);
    } else {
        arc(x, y, earthRadius * 2 + 32, earthRadius * 2 + 32,
                minAngle, minAngle + (maxAngle - minAngle) * healthRatio);
    }
    float seaColorR =  87 + healthRatio * ( 51 -  87);
    float seaColorG =  52 + healthRatio * (198 -  52);
    float seaColorB =  18 + healthRatio * (241 -  18);
    noStroke();
    fill(seaColorR, seaColorG, seaColorB);
    arc(x, y, earthRadius * 2, earthRadius * 2, minAngle, maxAngle);
    fill(earthColorR, earthColorG, earthColorB);
    displayClippedArc(x, y, earthRadius * 1.9, earthRadius * 1.9, 0.2 + angle, 0.9 + angle, minAngle, maxAngle);
    fill(seaColorR, seaColorG, seaColorB);
    arc(x, y, earthRadius * 1, earthRadius * 1, minAngle, maxAngle);
    fill(earthColorR, earthColorG, earthColorB);
    displayClippedArc(x, y, earthRadius * 1.8, earthRadius * 1.8, 0.4 + angle, 0.9 + angle, minAngle, maxAngle);
    fill(seaColorR, seaColorG, seaColorB);
    arc(x, y, earthRadius * 0.8, earthRadius * 0.8, minAngle, maxAngle);
    fill(earthColorR, earthColorG, earthColorB);
    displayClippedArc(x, y, earthRadius * 1.7, earthRadius * 1.7, 1.5 + angle, 2.8 + angle, minAngle, maxAngle);
    fill(seaColorR, seaColorG, seaColorB);
    arc(x, y, earthRadius * 0.7, earthRadius * 0.7, minAngle, maxAngle);
    fill(earthColorR, earthColorG, earthColorB);
    displayClippedArc(x, y, earthRadius * 1.3, earthRadius * 1.3, 2.9 + angle, 4.0 + angle, minAngle, maxAngle);
    fill(seaColorR, seaColorG, seaColorB);
    arc(x, y, earthRadius * 0.5, earthRadius * 0.5, minAngle, maxAngle);
    fill(earthColorR, earthColorG, earthColorB);
    displayClippedArc(x, y, earthRadius * 1.3, earthRadius * 1.3, 4.0 + angle, 6.0 + angle, minAngle, maxAngle);
    fill(seaColorR, seaColorG, seaColorB);
    arc(x, y, earthRadius * 0.3, earthRadius * 0.3, minAngle, maxAngle);
    float cloudColorR =  96 + healthRatio * (232 -  96);
    float cloudColorG =  96 + healthRatio * (241 -  96);
    float cloudColorB =  96 + healthRatio * (255 -  96);
    noFill();
    strokeWeight(earthRadius * 0.24);
    stroke(cloudColorR, cloudColorG, cloudColorB);
    displayClippedArc(x, y, earthRadius * 1.4, earthRadius * 1.4,
            0.31 + angle * 2, 0.65 + angle * 2, minAngle, maxAngle);
    displayClippedArc(x, y, earthRadius * 1.2, earthRadius * 1.2,
            1.31 + angle * 3.1, 1.85 + angle * 3.1, minAngle, maxAngle);
    displayClippedArc(x, y, earthRadius * 1.1, earthRadius * 1.1,
            2.12 + angle * 4.2, 3.35 + angle * 4.2, minAngle, maxAngle);
    displayClippedArc(x, y, earthRadius * 0.7, earthRadius * 0.7,
            4.54 + angle * 5.0, 5.91 + angle * 5.0, minAngle, maxAngle);
    displayClippedArc(x, y, earthRadius * 1.7, earthRadius * 1.7,
            2.54 + angle * 6.4, 3.51 + angle * 6.4, minAngle, maxAngle);
    displayClippedArc(x, y, earthRadius * 1.65, earthRadius * 1.65,
            4.11 + angle * 6.6, 4.43 + angle * 6.6, minAngle, maxAngle);

    strokeWeight(STROKE_WEIGHT);
}


void displayEnemy(float x, float y, float radius, color enemyColor, String enemyType, float angle) {
    noStroke();
    fill(enemyColor);
    ellipse(x, y, radius * 1.3, radius * 1.3);
    float tooth = PI / 12.0;
    if (enemyType.equals("Cannon")) {
        arc(x, y, radius * 2.0, radius * 2.0, 0 + tooth + angle,              PI / 2.0 - tooth + angle);
        arc(x, y, radius * 2.0, radius * 2.0, PI / 2.0 + tooth + angle,       PI - tooth + angle);
        arc(x, y, radius * 2.0, radius * 2.0, PI + tooth + angle,             3.0 * PI / 2.0 - tooth + angle);
        arc(x, y, radius * 2.0, radius * 2.0, 3.0 * PI / 2.0 + tooth + angle, 2.0 * PI - tooth + angle);
    } else if (enemyType.equals("Shield")) {
        arc(x, y, radius * 2.0, radius * 2.0, 0 + tooth + angle,              PI - tooth + angle);
        arc(x, y, radius * 2.0, radius * 2.0, PI + tooth + angle,             2.0 * PI - tooth + angle);
    } else if (enemyType.equals("BlackHole")) {
        arc(x, y, radius * 2.0, radius * 2.0, 0 + tooth + angle,              2.0 * PI / 3.0 - tooth + angle);
        arc(x, y, radius * 2.0, radius * 2.0, 2.0 * PI / 3.0 + tooth + angle, 4.0 * PI / 3.0 - tooth + angle);
        arc(x, y, radius * 2.0, radius * 2.0, 4.0 * PI / 3.0 + tooth + angle, 2.0 * PI - tooth + angle);
    }
    strokeWeight(STROKE_WEIGHT);
}


void displaySync(int currentSyncNumber) {
    fill(255, 0, 0, 255);
    rect(0, 0, machineScreenWidth, machineScreenHeight);
    textSize(512);
    stroke(255, 255);
    fill(255, 255);
    textAlign(CENTER, CENTER);
    text(new Integer(currentSyncNumber).toString(),
         0, 0, machineScreenWidth, machineScreenHeight);
}


void displayResume() {
    fill(255, 0, 0, 255);
    rect(0, 0, machineScreenWidth, machineScreenHeight);
    textSize(512);
    stroke(255, 255);
    fill(255, 255);
    textAlign(CENTER, CENTER);
    text("RESUME", 0, 0, machineScreenWidth, machineScreenHeight);
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


class EnemyCollisionAnimation extends Animation {
    float angle;
    color enemyColor;
    EnemyCollisionAnimation(float x, float y, float angle, color enemyColor) {
        super(x, y);
        this.angle = angle;
        this.enemyColor = enemyColor;
    }
    void display() {
        float angleWidth = PI * 0.8 * this.fade * this.fade * this.fade;
        float burstLength = 256 - 256 * this.fade * this.fade * this.fade;
        fill(this.enemyColor);
        noStroke();
        arc(this.x, this.y, burstLength, burstLength,
                this.angle - angleWidth, this.angle + angleWidth);
        super.display();
    }
}


class EnemyDestroyedAnimation extends Animation {
    color enemyColor;
    EnemyDestroyedAnimation(float x, float y, color enemyColor) {
        super(x, y);
        this.enemyColor = enemyColor;
    }
    void display() {
        float size = enemyRadius * 4.0;
        float ifade = (1.0 - this.fade);
        float drawSize = ifade * ifade * ifade * size;
        float drawStrokeWidth = this.fade * enemyRadius;
        noFill();
        strokeWeight(drawStrokeWidth);
        stroke(enemyColor);
        ellipse(this.x, this.y, drawSize * 2.0, drawSize * 2.0);
        strokeWeight(STROKE_WEIGHT);
        super.display();
    }
}


class CannonWeaponUsedAnimation extends Animation {
    color weaponColor;
    CannonWeaponUsedAnimation(float x, float y, color weaponColor) {
        super(x, y);
        this.weaponColor = weaponColor;
    }
    void display() {
        float size = weaponEllipseSize * (2.0 - this.fade);
        float fade = this.fade * this.fade;
        displayWeaponCannon(this.x, this.y, size, 0.0, this.weaponColor, fade);
        super.display();
    }
}


class MagnetWeaponUsedAnimation extends Animation {
    color weaponColor;
    MagnetWeaponUsedAnimation(float x, float y, color weaponColor) {
        super(x, y);
        this.weaponColor = weaponColor;
    }
    void display() {
        float size = weaponEllipseSize * (2.0 - this.fade);
        displayWeaponMagnet(this.x, this.y, size, 0.0, this.weaponColor, this.fade);
        super.display();
    }
}


