
private Minim minim;
private AudioSnippet dialogSound;
private AudioSnippet dialogClosedSound;
private AudioSnippet targetHitSound;
private AudioSnippet targetMissedSound;
private AudioSnippet trialEndedSound;


void initializeSound() {
    minim = new Minim(this);
    dialogSound       = minim.loadSnippet("../res/dialog.wav");
    dialogClosedSound = minim.loadSnippet("../res/dialog_closed.wav");
    targetHitSound    = minim.loadSnippet("../res/target_hit.wav");
    targetMissedSound = minim.loadSnippet("../res/target_missed.wav");
    trialEndedSound   = minim.loadSnippet("../res/trial_ended.wav");
}


void stopSound() {
    dialogSound.close();
    dialogClosedSound.close();
    targetHitSound.close();
    targetMissedSound.close();
    trialEndedSound.close();
    minim.stop();
    super.stop();
}


void playSoundDialog() {
    dialogSound.play(0);
}


void playSoundDialogClosed() {
    dialogClosedSound.play(0);
}


void playSoundTargetHit() {
    targetHitSound.play(0);
}


void playSoundTargetMissed() {
    targetMissedSound.play(0);
}


void playSoundTrialEnded() {
    trialEndedSound.play(0);
}
