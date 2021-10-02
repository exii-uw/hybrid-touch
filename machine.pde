
import java.net.InetAddress;
import java.net.UnknownHostException;


int machineScreenWidth = 0; // The width of the program window
int machineScreenHeight = 0; // The height of the program window
float machineVelocityScale = 0.0; // The machine velocity scale
float machineNoise = 0.0; // The noise to apply to touch inputs
float machineTrialScale; // How much to scale the trial script
PVector machineDialogPositions[]; // Where dialogs are drawn on screen
PVector machineTargetPracticeDialogPositions[]; // Where dialogs are drawn on screen


/**
 * Convert a vector in input space to machine space. This function is necessary
 * for the same reason getMachineScreenScale is necessary: touch inputs seem to
 * be mapped to a rectangle the size of a single screen on the powerwall, even
 * though the touch itself was across all 4x2 monitors.
 * @param input the vector in input space
 * @return the vector in machine space
 */
PVector inputSpaceToMachineSpace(PVector input) {
    return new PVector(input.x * machineScreenWidth / displayWidth,
                       input.y * machineScreenHeight / displayHeight);
}


/**
 * Initialize the program parameters that depend on the currently-running
 * machine.
 */
void initializeMachineSpecificParameters() {
    String machineName = null;
    Map<String, String> env = System.getenv();
    if (env.containsKey("COMPUTERNAME")) {
        machineName = env.get("COMPUTERNAME");
    } else if (env.containsKey("HOSTNAME")) {
        machineName = env.get("HOSTNAME");
    } else {
        try {
            machineName = InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException ex) {
            println("could not determine machine name");
            System.exit(1);
        }
    }

    PVector scale = getMachineScreenScale(machineName);
    if (scale == null) {
        System.out.printf("machine name %s does not have a specified screen scale\n", machineName);
        System.exit(1);
    }
    machineScreenWidth = (int) (displayWidth * scale.x);
    machineScreenHeight = (int) (displayHeight * scale.y);

    machineVelocityScale = getMachineCursorVelocityScale(machineName);
    if (machineVelocityScale == -1.0) {
        System.out.printf("machine name %s does not have a specified velocity scale\n", machineName);
        System.exit(1);
    }

    machineNoise = getMachineNoise(machineName);
    if (machineNoise == -1.0) {
        System.out.printf("machine name %s does not have a specified noise level\n", machineName);
        System.exit(1);
    }

    machineTrialScale = getMachineTrialScale(machineName);
    if (machineTrialScale == -1.0) {
        System.out.printf("machine name %s does not have a specified trial scale\n", machineName);
        System.exit(1);
    }

    machineDialogPositions = getMachineDialogPositions(machineName);
    if (machineDialogPositions == null) {
        System.out.printf("machine name %s does not have specified dialog positions\n", machineName);
        System.exit(1);
    }

    machineTargetPracticeDialogPositions = getMachineTargetPracticeDialogPositions(machineName);
    if (machineTargetPracticeDialogPositions == null) {
        System.out.printf("machine name %s does not have specified targer practice dialog positions\n", machineName);
        System.exit(1);
    }
}


/**
 * The regular screen scaling only covers one monitor on the Hci-Bigscreen
 * machine. This function returns the scale we actually want to use.
 * @param computerName the name of the current machine
 * @return PVector containing the screen scale for the current machine.
 */
private PVector getMachineScreenScale(String computerName) {
    String name = computerName.toLowerCase();
    if (name.equals("surin")) {                return new PVector(1, 1);
    } else if (name.equals("hci-bigscreen")) { return new PVector(4, 2);
    } else {                                   return null;
    }
}


/**
 * Testing on a small screen results in the cursor moving way too fast, or
 * testing on a large screen results in the cursor being too slow. This
 * function returns the scale for the cursor movements based on which
 * machine is running the program. Note that this doesn't apply to the
 * powerwall, despite it being huge; touch inputs are already scaled up
 * to the full size of the monitor. It's complicated, okay.
 * @param computerName the name of the current machine
 * @return the velocity scale
 */
private float getMachineCursorVelocityScale(String computerName) {
    String name = computerName.toLowerCase();
    if (name.equals("surin")) {                return 1.0;
    } else if (name.equals("hci-bigscreen")) { return 1.0;
    } else {                                   return -1.0; }
}


/**
 * The PowerWall inputs are somewhat noisy. These conditions are simluated
 * on non-noisy screens to help with testing.
 * @param computerName the name of the current machine
 * @return the quantization distance/noise range
 */
private float getMachineNoise(String computerName) {
    String name = computerName.toLowerCase();
    if (name.equals("surin")) {                return 0.0;
    } else if (name.equals("hci-bigscreen")) { return 0.0;
    } else {                                   return -1.0; }
}


/**
 * The scripts output by generate_script.py are designed for the PowerWall.
 * To test them on my laptop, they're scaled down.
 * @param computerName the name of the current machine
 * @return the scaling
 */
private float getMachineTrialScale(String computerName) {
    String name = computerName.toLowerCase();
    if (name.equals("surin")) {                return 0.25;
    } else if (name.equals("hci-bigscreen")) { return 1.0;
    } else {                                   return -1.0; }
}


/**
 * On the powerwall, we draw a dialog on every screen. On my laptop, just
 * one will suffice to prevent everything from dying.
 * @param computerName the name of the current machine
 * @return the positions
 */
private PVector[] getMachineDialogPositions(String computerName) {
    String name = computerName.toLowerCase();
    if (name.equals("surin")) {
        PVector positions[] = {
            new PVector(1.0/2.0, 1.0/2.0)
        };
        return positions;
    } else if (name.equals("hci-bigscreen")) {
        PVector positions[] = {
            new PVector(1.0/8.0, 1.0/4.0),
            new PVector(3.0/8.0, 1.0/4.0),
            new PVector(5.0/8.0, 1.0/4.0),
            new PVector(7.0/8.0, 1.0/4.0),
            new PVector(1.0/8.0, 3.0/4.0),
            new PVector(3.0/8.0, 3.0/4.0),
            new PVector(5.0/8.0, 3.0/4.0),
            new PVector(7.0/8.0, 3.0/4.0)
        };
        return positions;
    } else { return null; }
}


/**
 * We don't want to plaster the entire screen with the target practice dialogs,
 * since otherwise there won't be any place to put the targets.
 * @param computerName the name of the current machine
 * @return the positions
 */
private PVector[] getMachineTargetPracticeDialogPositions(String computerName) {
    String name = computerName.toLowerCase();
    if (name.equals("surin")) {
        PVector positions[] = {
            new PVector(1.0/2.0, 1.0/2.0)
        };
        return positions;
    } else if (name.equals("hci-bigscreen")) {
        PVector positions[] = {
            new PVector(1.0/8.0, 3.0/4.0),
            new PVector(7.0/8.0, 3.0/4.0)
        };
        return positions;
    } else { return null; }
}
