

final float PROGRESS_RING_TIME_INCREMENT = 1.0 / 60.0;
final float PROGRESS_RING_TIME_DECREMENT = 1.0 / 20.0;
final float PROGRESS_RING_PING_SPEED = 0.9;


final int DIALOG_HEIGHT = 700;
final int DIALOG_WIDTH = 900;
final float DIALOG_ANIMATION_SPEED = 0.8;
final float DIALOG_PROGRESS_RING_WIDTH = 192;


class ProgressRing {
    PVector[] positions;
    float width;
    float opacity;
    float time;
    long appearanceTime;
    boolean finished;
    boolean showing;
    float completedPingTime;
    boolean completedPinged;
    boolean beingTouched;
    ProgressRing(int numPositions) {
        this.positions = new PVector[numPositions];
        for (int i = 0; i < numPositions; ++i) {
            this.positions[i] = new PVector(0, 0);
        }
        this.width = 0;
        this.opacity = 255.0;
        this.time = 0.0;
        this.appearanceTime = System.currentTimeMillis();
        this.finished = false;
        this.showing = false;
        this.completedPingTime = 0.0;
        this.completedPinged = false;
        this.beingTouched = false;
    }
    void show() {
        this.time = 0.0;
        this.appearanceTime = System.currentTimeMillis();
        this.finished = false;
        this.showing = true;
        this.completedPingTime = 0.0;
        this.completedPinged = false;
    }
    void hide() {
        this.showing = false;
    }
    void update() {
        this.beingTouched = false;
        if (this.showing) {
            boolean touched = false;
            for (FilteredTouch touch: getFilteredTouches()) {
                for (PVector position: this.positions) {
                    if (touch.touchDownTime > this.appearanceTime
                     && touch.originX > position.x - this.width / 2
                     && touch.originX < position.x + this.width / 2
                     && touch.originY > position.y - this.width / 2
                     && touch.originY < position.y + this.width / 2
                     && touch.x > position.x - this.width / 2
                     && touch.x < position.x + this.width / 2
                     && touch.y > position.y - this.width / 2
                     && touch.y < position.y + this.width / 2) {
                        touched = true;
                    }
                }
            }
            if (touched) {
                this.beingTouched = true;
                if (this.time == 0) {
                    playSoundTargetHit();
                }
                this.time += PROGRESS_RING_TIME_INCREMENT;
                if (this.time >= 1.0) {
                    this.time = 1.0;
                    if (!this.completedPinged) {
                        this.completedPingTime = 1.0;
                        this.completedPinged = true;
                    }
                }
            } else {
                if (this.time >= 1.0) {
                    this.finished = true;
                } else if (!this.finished) {
                    this.time -= PROGRESS_RING_TIME_DECREMENT;
                    if (this.time <= 0.0) {
                        this.time = 0.0;
                    }
                }
            }
        }
        this.completedPingTime *= PROGRESS_RING_PING_SPEED;
    }
    void display(float x, float y) {
        displayProgressRing(x, y, this.width, this.time, this.opacity, this.completedPingTime);
    }
}


class Dialog {
    PVector[] positions;
    boolean showing;
    boolean finished;
    float animationTime;
    ProgressRing progressRing;
    /** How opaque the dialog currently is. */
    float opacity;
    /** How big the dialog currently is. */
    float scale;
    Dialog(PVector[] positions) {
        this.showing = false;
        this.finished = false;
        this.animationTime = 0.0;
        this.positions = new PVector[positions.length];
        for (int i = 0; i < positions.length; ++i) {
            this.positions[i] = new PVector(positions[i].x * machineScreenWidth,
                                            positions[i].y * machineScreenHeight);
        }
        this.progressRing = new ProgressRing(this.positions.length);
    }
    void showSound() {
        playSoundDialog();
    }
    void hideSound() {
        playSoundDialogClosed();
    }
    void show() {
        this.showing = true;
        this.finished = false;
        this.animationTime = 1.0;
        this.progressRing.show();
        showSound();
    }
    void hide() {
        this.showing = false;
        this.animationTime = 1.0;
        this.progressRing.hide();
        hideSound();
    }
    void update() {
        this.progressRing.update();
        if (this.progressRing.finished) {
            this.finished = true;
        }
        this.animationTime *= DIALOG_ANIMATION_SPEED;
    }
    void display() {
        if (this.showing) {
            this.opacity = (1 - this.animationTime) * 255;
            this.scale = 1 - this.animationTime * 0.2;
        } else {
            this.opacity = this.animationTime * 255;
            this.scale = 1 - (1 - this.animationTime) * 0.2;
        }
        if (this.opacity > 0.002) {
            for (int i = 0; i < this.positions.length; ++i) {
                PVector position = this.positions[i];
                if (this.positionShouldBeShown(position.x, position.y)) {
                    stroke(255, this.opacity * 0.5);
                    fill(55, this.opacity * 0.5);
                    rect(position.x - DIALOG_WIDTH / 2 * this.scale,
                         position.y - DIALOG_HEIGHT / 2 * this.scale,
                         DIALOG_WIDTH * this.scale,
                         DIALOG_HEIGHT * this.scale);
                    this.progressRing.positions[i].x = position.x;
                    this.progressRing.positions[i].y = position.y +
                                (DIALOG_HEIGHT / 2 - DIALOG_PROGRESS_RING_WIDTH) * this.scale;
                    this.progressRing.width = DIALOG_PROGRESS_RING_WIDTH * this.scale;
                    this.progressRing.opacity = this.opacity;
                    this.progressRing.display(this.progressRing.positions[i].x,
                                              this.progressRing.positions[i].y);
                }
            }
        }
    }
    boolean beingTouched() {
        return this.progressRing.beingTouched;
    }
    /**
     * Return true if placing a target here would put it behind this dialog window.
     */
    boolean targetIsBehindDialog(float x, float y, float radius) {
        for (int i = 0; i < this.positions.length; ++i) {
            PVector position = this.positions[i];
            if ((x + radius > position.x - DIALOG_WIDTH / 2) && (x - radius < position.x + DIALOG_WIDTH / 2)) {
                if ((y + radius > position.y - DIALOG_HEIGHT / 2) && (y - radius < position.y + DIALOG_HEIGHT / 2)) {
                    return true;
                }
            }
        }
        return false;
    }
    /**
     * Return true if this particular instance of the shown dialog should be shown.
     */
    boolean positionShouldBeShown(float x, float y) {
        return true;
    }
}


class InteractionModeDialog extends Dialog {
    String mode;
    InteractionModeDialog() {
        super(machineDialogPositions);
    }
    void display() {
        int top = 64;
        int spacing = 32;
        super.display();
        if (this.opacity <= 0.002) { return; }
        stroke(255, this.opacity);
        fill(255, this.opacity);
        for (PVector position: this.positions) {
            if (this.positionShouldBeShown(position.x, position.y)) {
                textSize(32 * this.scale);
                text("You're going to be using this interaction method.",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top) * this.scale - 12);
                textSize(48 * this.scale);
                text(this.mode,
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 2 * spacing) * this.scale - 12);
                textSize(32 * this.scale);
                text("Tap and hold OK to practice the technique.",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 48 + 4 * spacing) * this.scale - 12);
                text("The researcher will show you how it works.",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 48 + 32 + 5 * spacing) * this.scale - 12);
            }
        }
    }
}


class TargetWidthDialog extends Dialog {
    String lines[];
    TargetWidthDialog() {
        super(machineDialogPositions);
        this.lines = new String[3];
    }
    void setDisplayIntroText() {
        lines[0] = "Welcome to the experiment!";
        lines[1] = "Familiarize yourself with the touchscreen.";
        lines[2] = "When you're ready, tap and hold the OK button.";
    }
    void setDisplayOtherText() {
        lines[0] = "You're going to be clicking on a new size of targets.";
        lines[1] = "Feel free to take a break if you need one.";
        lines[2] = "When you're ready, tap and hold the OK button.";
    }
    void display() {
        int top = 128;
        int spacing = 48;
        super.display();
        if (this.opacity <= 0.002) { return; }
        stroke(255, this.opacity);
        fill(255, this.opacity);
        textSize(32 * this.scale);
        for (PVector position: this.positions) {
            if (this.positionShouldBeShown(position.x, position.y)) {
                text(lines[0],
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top) * this.scale - 12);
                text(lines[1],
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 1 * spacing) * this.scale - 12);
                text(lines[2],
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 32 + 2 * spacing) * this.scale - 12);
            }
        }
    }
}


class BigBlockDialog extends Dialog {
    String lines[];
    boolean displayStandingPosition;
    boolean displayTakeABreakText;
    float standingPosition;
    PVector storedPositions[];
    BigBlockDialog() {
        super(machineDialogPositions);
        this.lines = new String[3];
        this.displayStandingPosition = false;
        this.displayTakeABreakText = false;
        this.standingPosition = 0.0;
    }
    void setText() {
        if (this.displayStandingPosition) {
            if (this.displayTakeABreakText) {
                lines[0] = "Take a one-minute break if you're feeling tired.";
                lines[1] = "When you're ready, stand at the highlighted position.";
                lines[2] = "Then, tap and hold the OK button.";
            } else {
                lines[0] = "Stand at the highlighted position.";
                lines[1] = "";
                lines[2] = "When you're ready, tap and hold the OK button.";
            }
        } else {
            if (this.displayTakeABreakText) {
                lines[0] = "Take a one-minute break if you're feeling tired.";
                lines[1] = "";
                lines[2] = "When you're ready, tap and hold the OK button.";
            } else {
                lines[0] = "";
                lines[1] = "";
                lines[2] = "";
            }
        }
    }
    void setDisplayStandingPosition(boolean show, float position) {
        this.displayStandingPosition = show;
        this.standingPosition = position;
        this.setText();
    }
    void setDisplayTakeABreakText(boolean show) {
        this.displayTakeABreakText = show;
        this.setText();
    }
    boolean positionShouldBeShown(float x, float y) {
        if (this.displayStandingPosition) {
            return x > this.standingPosition - DIALOG_WIDTH / 2 && x < this.standingPosition + DIALOG_WIDTH / 2;
        } else {
            return true;
        }
    }
    void display() {
        int top = 128;
        int spacing = 48;
        super.display();
        if (this.opacity <= 0.002) { return; }
        stroke(255, this.opacity);
        fill(255, this.opacity);
        textSize(32 * this.scale);
        for (PVector position: this.positions) {
            if (this.positionShouldBeShown(position.x, position.y)) {
                text(lines[0],
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top) * this.scale - 12);
                text(lines[1],
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 1 * spacing) * this.scale - 12);
                text(lines[2],
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 32 + 2 * spacing) * this.scale - 12);
            }
        }
    }
}


class TargetPracticeDialog extends Dialog {
    TargetPracticeDialog() {
        super(machineTargetPracticeDialogPositions);
    }
    void display() {
        int top = 128;
        int spacing = 48;
        super.display();
        if (this.opacity <= 0.002) { return; }
        stroke(255, this.opacity);
        fill(255, this.opacity);
        textSize(32 * this.scale);
        for (PVector position: this.positions) {
            if (this.positionShouldBeShown(position.x, position.y)) {
                text("Give the interaction technique a try.",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top) * this.scale - 12);
                text("When you feel you're comfortable with the technique,",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 1 * spacing) * this.scale - 12);
                text("Tap and hold the OK button.",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 32 + 2 * spacing) * this.scale - 12);
            }
        }
    }
}


class ThankYouDialog extends Dialog {
    ThankYouDialog() {
        super(machineDialogPositions);
    }
    void showSound() {
        playSoundTrialEnded();
    }
    void display() {
        int top = 128;
        int spacing = 48;
        super.display();
        if (this.opacity <= 0.002) { return; }
        stroke(255, this.opacity);
        fill(255, this.opacity);
        textSize(32 * this.scale);
        for (PVector position: this.positions) {
            if (this.positionShouldBeShown(position.x, position.y)) {
                text("Thank you for your participation!",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top) * this.scale - 12);
                text("The trial is complete.",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 1 * spacing) * this.scale - 12);
                text("The researcher will take over from here.",
                     position.x - 4,
                     position.y + (-DIALOG_HEIGHT / 2 + top + 32 + 32 + 2 * spacing) * this.scale - 12);
            }
        }
    }
}
