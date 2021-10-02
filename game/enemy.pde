

private final float CANNON_ENEMY_SPEED = 4.0;
private final float CANNON_ENEMY_RADIUS = 32.0;
public float enemyRadius;


private List<Enemy> currentEnemyWave = new ArrayList<Enemy>();
private int currentEnemyWaveCursor = 0;
private List<Enemy> enemies = new ArrayList<Enemy>();
private List<Enemy> enemiesToRemove = new ArrayList<Enemy>();
private int nextEnemyId = 0;


/// These quantities are currently not used, but they may be useful for diagnostics.
private float enemySpeed;
private float subEnemySpeed;
private float flankEnemySpeed;
private float enemySpawnRate;
private float subEnemySpawnRate;
private float flankEnemySpawnRate;


private float enemySpawnTimer;
private float enemyAnimationTimer = 0.0;

private int currentWaveNumber = 0;


/**
 * Configure enemy behaviour based on the arguments given to the script.
 * These configuration values are currently not used as the values are also present in
 * each enemy script event, but they may be useful to have around.
 */
void configureEnemies(JsonObject arguments) {
    enemySpeed = (float) arguments.getJsonNumber("enemy_speed").doubleValue();
    subEnemySpeed = (float) arguments.getJsonNumber("sub_enemy_speed").doubleValue();
    flankEnemySpeed = (float) arguments.getJsonNumber("flank_enemy_speed").doubleValue();
    enemySpawnRate = (float) arguments.getJsonNumber("enemy_spawn_rate").doubleValue();
    subEnemySpawnRate = (float) arguments.getJsonNumber("sub_enemy_spawn_rate").doubleValue();
    flankEnemySpawnRate = (float) arguments.getJsonNumber("flank_enemy_spawn_rate").doubleValue();

    enemyRadius = CANNON_ENEMY_RADIUS;
}


/**
 * Begin a new wave of enemies. All enemies that currently exist will
 * be despawned.
 */
void beginNewWave() {
    for (Enemy enemy: enemies) {
        enemiesToRemove.add(enemy);
    }
    for (Enemy enemy: enemiesToRemove) {
        enemies.remove(enemy);
    }
    enemies.clear();
    enemiesToRemove.clear();
    currentEnemyWaveCursor = 0;
    currentEnemyWave.clear();
    enemySpawnTimer = 0.0;
    ++currentWaveNumber;
}


/**
 * Return a list of all enemies that are active on-screen. This list should
 * be considered read-only, and should not be edited by outside code. This
 * list is not changed by methods like `Enemy.kill`, so do not assume that
 * all enemies in it are currently alive.
 *
 * @return read-only list containing all active enemies
 */
List<Enemy> getEnemies() {
    return enemies;
}


/**
 * Return the index of the current wave. Goes from 1 to however many waves
 * there are in the program, and does not reset.
 */
int getCurrentWaveNumber() {
    return currentWaveNumber;
}


/**
 * Add an enemy to the current wave of enemies.
 */
void addEnemy(String type, float angle, float speed, float spawnTime) {
    // Push enemies out to the edge of a circle that's just outside the corners
    // of the game viewport.
    float enemySpawnDistance = enemyRadius + (float) Math.sqrt(
            machineScreenWidth * machineScreenWidth * 0.5 +
            machineScreenHeight * machineScreenHeight * 0.5);
    float sin = (float) Math.sin(angle / 180.0 * PI);
    float cos = (float) Math.cos(angle / 180.0 * PI);
    float x = cos * enemySpawnDistance + machineScreenWidth * 0.5;
    float y = sin * enemySpawnDistance + machineScreenHeight * 0.5;
    float vx = -cos * speed * machineTrialScale;
    float vy = -sin * speed * machineTrialScale;
    // Try to push the enemies closer to the screen so that they spawn a bit
    // more quickly. I'm sure there's a fancy
    // trig thing where I just compute the intersection of the enemy and the
    // outer walls but I don't CARE, who CARES
    float dx = -cos * 4.0;
    float dy = -sin * 4.0;
    while ((x + dx < -CANNON_ENEMY_RADIUS || x + dx > machineScreenWidth + CANNON_ENEMY_RADIUS) ||
           (y + dy < -CANNON_ENEMY_RADIUS || y + dy > machineScreenHeight + CANNON_ENEMY_RADIUS)) {
        x += dx;
        y += dy;
    }
    if (type.equals("Enemy." + CannonEnemy.TYPE)) {
        currentEnemyWave.add(new CannonEnemy(x, y, vx, vy, spawnTime));
    } else if (type.equals("Enemy." + ShieldEnemy.TYPE)) {
        currentEnemyWave.add(new ShieldEnemy(x, y, vx, vy, spawnTime));
    } else if (type.equals("Enemy." + BlackHoleEnemy.TYPE)) {
        currentEnemyWave.add(new BlackHoleEnemy(x, y, vx, vy, spawnTime));
    } else {
        System.out.printf("Unrecognized enemy type %s", type);
        return;
    }
    Enemy enemy = currentEnemyWave.get(currentEnemyWave.size() - 1);
    logEvent(new HybridEnemySpawnedEvent(enemy.id, enemy.x, enemy.y, enemy.radius, enemy.enemyType()));
}


/**
 * Spawn an enemy from the current wave. The cursor will be moved forward.
 */
void spawnEnemy() {
    if (currentEnemyWaveCursor >= currentEnemyWave.size()) {
        return;
    }
    enemies.add(currentEnemyWave.get(currentEnemyWaveCursor++));
}


/**
 * Show all enemies that are currently active (alive or dead.)
 */
void displayEnemies() {
    enemyAnimationTimer = (enemyAnimationTimer + 0.03) % (PI * 2.0);
    for (Enemy enemy: enemies) {
        enemy.display();
    }
}


/**
 * Increment the enemy timer and spawn new enemies as necessary, and move
 * all existing enemies, removing any that have been killed.
 *
 * @callback registerCollisionWithEarth(dx, dy) is called with the enemy's
 * displacement from the centre of the earth whenever it collides with the
 * earth's surface.
 */
void updateEnemies(float earthX, float earthY, float earthRadius) {
    for (Enemy enemy: enemies) {
        enemy.update();
        if (enemy.needsRemoval()) {
            enemiesToRemove.add(enemy);
        }
    }
    for (Enemy enemy: enemiesToRemove) {
        enemies.remove(enemy);
    }
    if (enemies.size() == 0 && enemiesToRemove.size() != 0) {
        // Callback to game.pde
        registerWaveCompleted();
    }
    enemiesToRemove.clear();

    float collisionRadius = earthRadius + enemyRadius;
    for (Enemy enemy: enemies) {
        float dx = enemy.x - earthX;
        float dy = enemy.y - earthY;
        if (dx * dx + dy * dy < collisionRadius * collisionRadius) {
            enemy.collide();
            registerCollisionWithEarth(dx, dy);
        }
    }

    enemySpawnTimer += 0.033;
    while (currentEnemyWaveCursor < currentEnemyWave.size()) {
        Enemy currentEnemy = currentEnemyWave.get(currentEnemyWaveCursor);
        float spawnTime = currentEnemy.spawnTime;
        if (enemySpawnTimer >= spawnTime) {
            enemySpawnTimer -= spawnTime;
            spawnEnemy();
        } else {
            break;
        }
    }
}


/**
 * Kill an enemy, maybe. For debugging purposes.
 */
void killArbitraryEnemy() {
    for (Enemy enemy: enemies) {
        float dx = enemy.x - machineScreenWidth / 2.0;
        float dy = enemy.y - machineScreenHeight / 2.0;
        if (dx * dx + dy * dy < earthRadius * earthRadius * 16.0) {
            enemy.kill("hypertap", "hypertap", 0, 0.0, 0.0);
            creditParticipant(getWorkspaces().get(0).participantIdentifier, 
                    "Weapon.HyperTap", enemy.x, enemy.y,
                    enemy.id, enemy.x, enemy.y,
                    null, "HyperTap");
            break;
        }
    }
}


abstract class Enemy {
    int id;
    float x;
    float y;
    float radius;
    float spawnTime;

    boolean dead = false;

    abstract String enemyType();
    abstract color enemyColor();
    abstract void update();
    abstract void display();

    /**
     * Remove an enemy from the scene after it fell out of the interaction area.
     */
    void despawn() {
        this.dead = true;
        logEvent(new HybridEnemyDespawnedEvent(this.id));
    }

    /**
     * Remove an enemy from the scene and log that the enemy collided with the
     * earth.
     */
    void collide() {
        this.dead = true;
        logEvent(new HybridEnemyCollideEvent(this.id));
        playSoundEnemyCollided();
    }

    /**
     * Remove an enemy from the scene and log that the enemy was killed by user
     * action.
     */
    void kill(String participant, String source, int cid, float cx, float cy) {
        this.dead = true;
        logEvent(new HybridEnemyHitEvent(participant, source, cid, cx, cy,
                    this.id, this.x, this.y, this.radius, "Enemy." + this.enemyType()));
        createAnimation(new EnemyDestroyedAnimation(x, y, this.enemyColor()));
        playSoundEnemyKilled();
    }
    boolean needsRemoval() {
        return this.dead == true;
    }
}


class CannonEnemy extends Enemy {
    public final color COLOR = color(215, 55, 5);
    public final static String TYPE = "Cannon";
    float vx;
    float vy;
    CannonEnemy(float x, float y, float vx, float vy, float spawnTime) {
        this.id = nextEnemyId++;
        this.x = x;
        this.y = y;
        this.vx = vx;
        this.vy = vy;
        this.radius = enemyRadius;
        this.spawnTime = spawnTime;
    }
    String enemyType() {
        return this.TYPE;
    }
    color enemyColor() {
        return this.COLOR;
    }
    void update() {
        this.x += this.vx * machineTrialScale;
        this.y += this.vy * machineTrialScale;
        logEvent(new HybridEnemyMovedEvent(this.id, this.x, this.y));
        if ((this.x < -16.0 && this.vx < 0.0) || (this.y < -16.0 && this.vy < 0.0) ||
            (this.x > machineScreenWidth + 16.0 && this.vx > 0.0) ||
            (this.y > machineScreenHeight + 16.0 && this.vy > 0.0)) {
            this.despawn();
        }
    }
    void display() {
        displayEnemy(this.x, this.y, this.radius, this.enemyColor(), this.enemyType(), enemyAnimationTimer);
    }
    void collide() {
        float angle = (float) Math.atan2(-this.vy, -this.vx);
        createAnimation(new EnemyCollisionAnimation(x, y, angle, this.enemyColor()));
        super.collide();
    }
}


class ShieldEnemy extends Enemy {
    public final color COLOR = color(65, 255, 5);
    public final static String TYPE = "Shield";
    float vx;
    float vy;
    ShieldEnemy(float x, float y, float vx, float vy, float spawnTime) {
        this.id = nextEnemyId++;
        this.x = x;
        this.y = y;
        this.vx = vx;
        this.vy = vy;
        this.radius = enemyRadius;
        this.spawnTime = spawnTime;
    }
    String enemyType() {
        return this.TYPE;
    }
    color enemyColor() {
        return this.COLOR;
    }
    void update() {
        this.x += this.vx * machineTrialScale;
        this.y += this.vy * machineTrialScale;
        logEvent(new HybridEnemyMovedEvent(this.id, this.x, this.y));
        if ((this.x < -16.0 && this.vx < 0.0) || (this.y < -16.0 && this.vy < 0.0) ||
            (this.x > machineScreenWidth + 16.0 && this.vx > 0.0) ||
            (this.y > machineScreenHeight + 16.0 && this.vy > 0.0)) {
            this.despawn();
        }
    }
    void display() {
        displayEnemy(this.x, this.y, this.radius, this.enemyColor(), this.enemyType(), enemyAnimationTimer);
    }
    void collide() {
        float angle = (float) Math.atan2(-this.vy, -this.vx);
        createAnimation(new EnemyCollisionAnimation(x, y, angle, this.enemyColor()));
        super.collide();
    }
}


class BlackHoleEnemy extends Enemy {
    public final color COLOR = color(15, 105, 255);
    public final static String TYPE = "BlackHole";
    float vx;
    float vy;
    BlackHoleEnemy(float x, float y, float vx, float vy, float spawnTime) {
        this.id = nextEnemyId++;
        this.x = x;
        this.y = y;
        this.vx = vx;
        this.vy = vy;
        this.radius = enemyRadius;
        this.spawnTime = spawnTime;
    }
    String enemyType() {
        return this.TYPE;
    }
    color enemyColor() {
        return this.COLOR;
    }
    void update() {
        this.x += this.vx * machineTrialScale;
        this.y += this.vy * machineTrialScale;
        logEvent(new HybridEnemyMovedEvent(this.id, this.x, this.y));
        if ((this.x < -16.0 && this.vx < 0.0) || (this.y < -16.0 && this.vy < 0.0) ||
            (this.x > machineScreenWidth + 16.0 && this.vx > 0.0) ||
            (this.y > machineScreenHeight + 16.0 && this.vy > 0.0)) {
            this.despawn();
        }
    }
    void display() {
        displayEnemy(this.x, this.y, this.radius, this.enemyColor(), this.enemyType(), enemyAnimationTimer);
    }
    void collide() {
        float angle = (float) Math.atan2(-this.vy, -this.vx);
        createAnimation(new EnemyCollisionAnimation(x, y, angle, this.enemyColor()));
        super.collide();
    }
}
