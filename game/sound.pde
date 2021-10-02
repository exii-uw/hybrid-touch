
private Minim minim;
private AudioCue dialogSound;
private AudioCue dialogClosedSound;
private AudioCue enemyKilledSound;
private AudioCue enemyCollidedSound;
private AudioCue trialEndedSound;

private final int SOUND_TIMEOUT = 4;


private class AudioCue {
    int timeout;
    AudioSnippet snippet;
    AudioCue(String path) {
        this.timeout = 0;
        this.snippet = minim.loadSnippet(path);
    }
    void update() {
        this.timeout -= 1;
        if (this.timeout < 0) {
            this.timeout = 0;
        }
    }
    void play(int offset) {
        if (this.timeout <= 0) {
            this.snippet.play(offset);
            this.timeout = SOUND_TIMEOUT;
        }
    }
    void close() {
        this.snippet.close();
    }
}


void initializeSound() {
    minim = new Minim(this);
    dialogSound        = new AudioCue("../res/dialog.wav");
    dialogClosedSound  = new AudioCue("../res/dialog_closed.wav");
    enemyKilledSound   = new AudioCue("../res/target_hit.wav");
    enemyCollidedSound = new AudioCue("../res/target_missed.wav");
    trialEndedSound    = new AudioCue("../res/trial_ended.wav");
}


void stopSound() {
    dialogSound.close();
    dialogClosedSound.close();
    enemyKilledSound.close();
    enemyCollidedSound.close();
    trialEndedSound.close();
    minim.stop();
    super.stop();
}


void updateSound() {
    dialogSound.update();
    dialogClosedSound.update();
    enemyKilledSound.update();
    enemyCollidedSound.update();
    trialEndedSound.update();
}


void playSoundDialog() {
    dialogSound.play(0);
}


void playSoundDialogClosed() {
    dialogClosedSound.play(0);
}


void playSoundEnemyKilled() {
    enemyKilledSound.play(0);
}


void playSoundEnemyCollided() {
    enemyCollidedSound.play(0);
}


void playSoundTrialEnded() {
    trialEndedSound.play(0);
}
