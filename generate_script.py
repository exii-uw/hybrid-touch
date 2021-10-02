#!/usr/bin/env python3

import sys
import math
import json
import random
import itertools

# http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.62.7409&rep=rep1&type=pdf
interaction_modes = ['HybridMode.Absolute',
                     #'HybridMode.Pull',
                     'HybridMode.Drag',
                     'HybridMode.CursorTap',
                     #'HybridMode.CursorLift',
                     ]

original_screen_size = (500, 180) # centimetres
original_screen_resolution = (4730, 1730)
original_screen_pixel_density = 9.46 # pixels/cm
original_target_distances_in_pixels = [946, 1892, 2838, 3784]
original_target_distances_in_centimetres = [100, 200, 300, 400]
original_target_widths_in_pixels = [8, 16, 32, 64]
original_target_widths_in_centimetres = [0.85, 1.70, 3.38, 6.77]


our_screen_size = (413, 117) # centimetres
our_screen_resolution = (7680, 2160)
our_screen_pixel_density = our_screen_resolution[0] / our_screen_size[0]
our_screen_vertical_seams = [our_screen_resolution[0] / 4,
                             our_screen_resolution[0] / 2,
                             our_screen_resolution[0] * 3 / 4]
our_screen_horizontal_seams = [our_screen_resolution[1] / 2]
our_screen_border = 256
our_target_distances_in_centimetres = [100, 183.33, 266.66, 350] # 4 metres is just too damn far.
# our_target_widths_in_centimetres = [3.38, (3.38 + 6.77) / 2, 6.77, 6.77 * 1.5] # TOO DAMN SMALL
our_target_widths_in_centimetres = [5.08, 10.16]
our_target_distances_in_pixels = [our_screen_pixel_density * d for d in our_target_distances_in_centimetres]
our_target_widths_in_pixels = [our_screen_pixel_density * w for w in our_target_widths_in_centimetres]
our_standing_positions = [our_screen_resolution[0] / 8, our_screen_resolution[0] * 7 / 8]


angle_candidates = list(range(720))


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Generate a script for running a trial.')
    parser.add_argument('--mode', help='specify an interaction mode. if none are specified, all will be included')
    parser.add_argument('--blocks', help='number of blocks', type=int, default=4)
    parser.add_argument('--repetitions', help='number of repetitions', type=int, default=3)
    subparser = parser.add_subparsers(dest='subparser')
    latin = subparser.add_parser('permute',
                                 help="permute an existing script's interaction modes and standing positions")
    latin = subparser.add_parser('swap-side',
                                 help="swap which side of the screen the user is standing on")
    random = subparser.add_parser('random',
                                  help="generate a trial that jumps around arbitrarily")
    radial = subparser.add_parser('radial',
                                   help="generate a trial with distance from centre")
    vertical = subparser.add_parser('vertical',
                                     help="generate a trial that moves up and down")
    rectangular = subparser.add_parser('rectangular',
                                        help="generate a trial that moves in a rectangle")
    strict_rectangular = subparser.add_parser('strict-rectangular',
                                        help="generate a trial that moves in a non-random rectangle\n"
                                        "(repetitions is number of backtracks, blocks is number of full "
                                        "rectangle traverals)")
    aligned_rectangular = subparser.add_parser('aligned-rectangular',
                                        help="generate a trial that moves in a non-random rectangle,\n"
                                        "with edges of rectangle aligned to standing positions\n"
                                        "(repetitions is number of backtracks, blocks is number of full "
                                        "rectangle traverals)")
    arguments = parser.parse_args()
    if arguments.subparser == 'permute':
        do_latin()
    elif arguments.subparser == 'swap-side':
        do_swap_side()
    elif arguments.subparser == 'radial':
        do_radial(arguments.blocks, arguments.repetitions)
    elif arguments.subparser == 'vertical':
        do_vertical(arguments.blocks, arguments.repetitions)
    elif arguments.subparser == 'rectangular':
        do_rectangular(arguments.blocks, arguments.repetitions)
    elif arguments.subparser == 'strict-rectangular':
        do_strict_rectangular(arguments.blocks, arguments.repetitions)
    elif arguments.subparser == 'aligned-rectangular':
        do_aligned_rectangular(arguments.blocks, arguments.repetitions)
    elif arguments.subparser == 'random':
        if arguments.mode:
            do_single_mode(arguments.mode, arguments.blocks, arguments.repetitions)
        else:
            do_multi_mode(arguments.blocks, arguments.repetitions)
    else:
        raise TypeError()


def do_single_mode(mode, blocks, repetitions):
    target_distances = our_target_distances_in_pixels * repetitions
    print('Script.Start,' + json.dumps({
        'multiple_modes': 0,
        'target_distances': our_target_distances_in_pixels,
        'target_widths': our_target_widths_in_pixels,
    }))
    print('Script.InteractionMode,' + json.dumps({
        'mode': mode,
    }))
    random.shuffle(our_target_widths_in_pixels)
    for target_width in our_target_widths_in_pixels:
        print('Script.TargetWidth,' + json.dumps({
            'target_width': target_width,
        }))
        for _ in range(blocks):
            block = generate_width_block(target_width, target_distances)
            print('Script.BeginBlock,' + json.dumps({
                'run_length': len(block)
            }))
            iter_block = iter(block)
            discarded_target = next(iter_block)
            print('Script.ShowDiscardedTarget,' + json.dumps({
                'x': discarded_target[0],
                'y': discarded_target[1],
                'w': target_width,
                'h': target_width,
                'distance': discarded_target[2],
            }))
            for target in iter_block:
                print('Script.ShowTarget,' + json.dumps({
                    'x': target[0],
                    'y': target[1],
                    'w': target_width,
                    'h': target_width,
                    'distance': target[2],
                }))


def do_multi_mode(blocks, repetitions):
    target_distances = our_target_distances_in_pixels * repetitions
    print('Script.Start,' + json.dumps({
        'multiple_modes': 1,
        'target_distances': our_target_distances_in_pixels,
        'target_widths': our_target_widths_in_pixels,
    }))
    random.shuffle(interaction_modes)
    for mode in interaction_modes:
        print('Script.InteractionMode,' + json.dumps({
            'mode': mode,
        }))
        random.shuffle(our_target_widths_in_pixels)
        for target_width in our_target_widths_in_pixels:
            print('Script.TargetWidth,' + json.dumps({
                'target_width': target_width,
            }))
            for _ in range(blocks):
                block = generate_width_block(target_width, target_distances)
                print('Script.BeginBlock,' + json.dumps({
                    'run_length': len(block)
                }))
                iter_block = iter(block)
                discarded_target = next(iter_block)
                print('Script.ShowDiscardedTarget,' + json.dumps({
                    'x': discarded_target[0],
                    'y': discarded_target[1],
                    'w': target_width,
                    'h': target_width,
                    'distance': discarded_target[2],
                }))
                for target in iter_block:
                    print('Script.ShowTarget,' + json.dumps({
                        'x': target[0],
                        'y': target[1],
                        'w': target_width,
                        'h': target_width,
                        'distance': target[2],
                    }))


def do_latin():
    positions = []
    modes = []
    lines = []
    for line in sys.stdin:
        if line.startswith('Script.InteractionMode'):
            modes.append(line)
            lines.append('mode')
        elif line.startswith('Script.BeginBigBlock'):
            positions.append(line)
            lines.append('position')
        else:
            lines.append(line)
    modes = modes[1:] + [modes[0]]
    modes = modes[::-1]
    positions = positions[1:] + [positions[0]]
    for line in lines:
        if line == 'mode':
            sys.stdout.write(modes.pop())
        elif line == 'position':
            sys.stdout.write(positions.pop())
        else:
            sys.stdout.write(line)
    return


def do_swap_side():
    for line in sys.stdin:
        if line.startswith('Script.ShowTarget') or \
           line.startswith('Script.ShowDiscardedTarget') or \
           line.startswith('Script.ShowTargetIndicator') or \
           line.startswith('Script.BeginBigBlock'):
            identifier, _, data = line.partition(',')
            data_dict = json.loads(data)
            if 'x' in data_dict:
                data_dict['x'] = our_screen_resolution[0] - data_dict['x']
            if 'standing_x' in data_dict:
                data_dict['standing_x'] = our_screen_resolution[0] - data_dict['standing_x']
            print(identifier + ',' + json.dumps(data_dict))
        else:
            sys.stdout.write(line)
    return


def do_radial(blocks, repetitions):
    target_distances = our_target_distances_in_pixels * repetitions
    print('Script.Start,' + json.dumps({
        'multiple_modes': 1,
        'target_distances': our_target_distances_in_pixels,
        'target_widths': our_target_widths_in_pixels,
    }))
    random.shuffle(interaction_modes)
    for mode in interaction_modes:
        print('Script.InteractionMode,' + json.dumps({
            'mode': mode,
        }))
        random.shuffle(our_target_widths_in_pixels)
        for target_width in our_target_widths_in_pixels:
            print('Script.TargetWidth,' + json.dumps({
                'target_width': target_width,
            }))
            random.shuffle(our_target_distances_in_pixels)
            for target_distance in our_target_distances_in_pixels:
                run_length = blocks * repetitions + 1
                print('Script.BeginBlock,' + json.dumps({
                    'run_length': run_length,
                    'distance': target_distance,
                }))
                sys.stdout.flush()
                screen_position = lambda x, y: (x + our_screen_resolution[0] * 0.5, y + our_screen_resolution[1] * 0.5)
                target_list = []
                while True:
                    distance_to_cover = max(our_target_widths_in_pixels) * 1.5
                    # Complicated trigonometry goes here
                    cos_angle = distance_to_cover ** 2 / (2 * target_distance ** 2) - 1
                    sin_angle = math.sqrt(1 - cos_angle ** 2)
                    radius = math.sqrt(target_distance * target_distance / (2 * (1 - cos_angle)))
                    rotate = lambda x, y, cos_angle, sin_angle: (x * cos_angle + y * -sin_angle,
                                                                 x * sin_angle + y *  cos_angle)
                    last_x, last_y = (0.0, 0.0)
                    # Start at a random distance above the horizon, maybe?
                    y = (target_width * 0.25) * random.choice((-1, 1))
                    x = math.sqrt(radius ** 2 - y ** 2) * random.choice((-1, 1))

                    screen_x, screen_y = screen_position(x, y)
                    direction = 1.0
                    for _ in range(run_length):
                        # Position on screen from centre of screen
                        if not target_is_onscreen_and_not_on_seam(screen_x, screen_y, target_width):
                            # The target is offscreen -- turn around and start moving
                            # in the other direction. Do so twice, so we don't repeat
                            # the last position.
                            direction = -direction
                            x, y = rotate(x, y, cos_angle, sin_angle * direction)
                            x, y = rotate(x, y, cos_angle, sin_angle * direction)
                            screen_x, screen_y = screen_position(x, y)
                            if not target_is_onscreen_and_not_on_seam(screen_x, screen_y, target_width):
                                # Target is still not onscreen even after turning
                                # around. We started in a bad position.
                                # print('OFF', file=sys.stderr); sys.stderr.flush()
                                target_list.clear()
                                break
                        target_list.append((screen_x, screen_y, euclidean_distance(x, y, last_x, last_y)))
                        last_x, last_y = x, y
                        x, y = rotate(x, y, cos_angle, sin_angle * direction)
                        screen_x, screen_y = screen_position(x, y)
                    else:
                        break
                iter_target_list = iter(target_list)
                x, y, d = next(iter_target_list)
                print('Script.ShowDiscardedTarget,' + json.dumps({
                    'x': x,
                    'y': y,
                    'w': target_width,
                    'h': target_width,
                    'distance': d,
                }))
                for x, y, d in iter_target_list:
                    print('Script.ShowTarget,' + json.dumps({
                        'x': x,
                        'y': y,
                        'w': target_width,
                        'h': target_width,
                        'distance': d,
                    }))
                sys.stdout.flush()


def do_vertical(blocks, repetitions):
    target_distances = our_target_distances_in_pixels * repetitions
    print('Script.Start,' + json.dumps({
        'multiple_modes': 1,
        'target_distances': our_target_distances_in_pixels,
        'target_widths': our_target_widths_in_pixels,
    }))
    random.shuffle(interaction_modes)
    for mode in interaction_modes:
        print('Script.InteractionMode,' + json.dumps({
            'mode': mode,
        }))
        random.shuffle(our_target_widths_in_pixels)
        for target_width in our_target_widths_in_pixels:
            print('Script.TargetWidth,' + json.dumps({
                'target_width': target_width,
            }))
            random.shuffle(our_target_distances_in_pixels)
            for target_distance in our_target_distances_in_pixels:
                run_length = blocks * repetitions + 1
                print('Script.BeginBlock,' + json.dumps({
                    'run_length': run_length,
                    'distance': target_distance,
                }))
                sys.stdout.flush()
                target_list = []
                while True:
                    v_delta = (our_screen_resolution[1] - target_width * 1.1) * random.uniform(1/12, 1/3)
                    h_delta = math.sqrt(target_distance ** 2.0 - v_delta ** 2.0)

                    last_x, last_y = (0.0, 0.0)
                    v_direction = random.choice((-1.0, 1.0))
                    h_direction = random.choice((-1.0, 1.0))
                    x = our_screen_resolution[0] * 0.5 + h_delta * 0.5 * -h_direction
                    y = our_screen_resolution[1] * 0.5 + v_delta * 0.5 * -v_direction

                    for _ in range(run_length):
                        if target_is_on_seam(x, y, target_width):
                            # print("SEAM", x, y, file=sys.stderr); sys.stderr.flush()
                            target_list.clear()
                            break
                        if not target_is_onscreen(x, y, target_width):
                            v_direction = -v_direction
                            y = y + v_direction * v_delta * 2;
                            if not target_is_onscreen_and_not_on_seam(x, y, target_width):
                                # Target is still not onscreen even after turning
                                # around. We started in a bad position.
                                target_list.clear()
                                # print(x, y, file=sys.stderr); sys.stderr.flush()
                                break
                        target_list.append((x, y, euclidean_distance(x, y, last_x, last_y)))
                        last_x, last_y = x, y
                        x, y = x + h_direction * h_delta, y + v_direction * v_delta
                        h_direction = -h_direction
                    else:
                        break
                iter_target_list = iter(target_list)
                x, y, d = next(iter_target_list)
                print('Script.ShowDiscardedTarget,' + json.dumps({
                    'x': x,
                    'y': y,
                    'w': target_width,
                    'h': target_width,
                    'distance': d,
                }))
                for x, y, d in iter_target_list:
                    print('Script.ShowTarget,' + json.dumps({
                        'x': x,
                        'y': y,
                        'w': target_width,
                        'h': target_width,
                        'distance': d,
                    }))
                sys.stdout.flush()


def do_rectangular(blocks, repetitions):
    target_distances = our_target_distances_in_pixels * repetitions
    print('Script.Start,' + json.dumps({
        'multiple_modes': 1,
        'target_distances': our_target_distances_in_pixels,
        'target_widths': our_target_widths_in_pixels,
    }))
    random.shuffle(interaction_modes)
    for mode in interaction_modes:
        print('Script.InteractionMode,' + json.dumps({
            'mode': mode,
        }))
        random.shuffle(our_target_widths_in_pixels)
        for target_width in our_target_widths_in_pixels:
            print('Script.TargetWidth,' + json.dumps({
                'target_width': target_width,
            }))
            random.shuffle(our_target_distances_in_pixels)
            for target_distance in our_target_distances_in_pixels:
                run_length = ((blocks * repetitions) & ~1) + 1
                print('Script.BeginBlock,' + json.dumps({
                    'run_length': run_length,
                    'distance': target_distance,
                }))
                sys.stdout.flush()

                verticals = (run_length // 3) & ~1
                vertical_distance = min(our_target_distances_in_pixels)
                x = our_screen_resolution[0] * 0.5 + target_distance * random.choice((-0.5, 0.5))
                y = our_screen_resolution[1] * 0.5 + vertical_distance * random.choice((-0.5, 0.5))
                horizontal_swap = lambda x, y: ((x - target_distance if x > our_screen_resolution[0] * 0.5
                                                                     else x + target_distance), y)
                vertical_swap = lambda x, y: (x, (y - vertical_distance if y > our_screen_resolution[1] * 0.5
                                                                        else y + vertical_distance))
                possible_vertical_swap_positions = list(range(run_length // 2))
                vertical_swap_positions = set(random.sample(possible_vertical_swap_positions, verticals))
                vertical_swap_positions |= {run_length - 1 - i for i in vertical_swap_positions}

                print('Script.ShowDiscardedTarget,' + json.dumps({
                    'x': x,
                    'y': y,
                    'w': target_width,
                    'h': target_width,
                    'distance': 0.0,
                }))
                for i in range(run_length - 1):
                    last_x, last_y = x, y
                    if i in vertical_swap_positions:
                        x, y = vertical_swap(x, y)
                    else:
                        x, y = horizontal_swap(x, y)
                    print('Script.ShowTarget,' + json.dumps({
                        'x': x,
                        'y': y,
                        'w': target_width,
                        'h': target_width,
                        'distance': euclidean_distance(x, y, last_x, last_y),
                    }))
                sys.stdout.flush()


def do_strict_rectangular(blocks, repetitions):
    target_distances = our_target_distances_in_pixels * repetitions
    print('Script.Start,' + json.dumps({
        'multiple_modes': 1,
        'target_distances': our_target_distances_in_pixels,
        'target_widths': our_target_widths_in_pixels,
    }))
    random.shuffle(interaction_modes)
    for mode in interaction_modes:
        print('Script.InteractionMode,' + json.dumps({
            'mode': mode,
        }))
        our_target_distances_in_pixels.sort();
        minimum_distance, rest_of_distances = our_target_distances_in_pixels[0], our_target_distances_in_pixels[1:];
        # For the first run, do the longest distance first, as that will
        # encourage people to use the distance interaction technique from
        # the outset.
        rest_of_distances = sorted(rest_of_distances)[::-1]
        widths_and_distances = []
        for i in range(blocks):
            random.shuffle(our_target_widths_in_pixels)
            for width in our_target_widths_in_pixels:
                for distance in rest_of_distances:
                    widths_and_distances.append((width, distance))
                # For the rest of the runs, use a random order for distances.
                random.shuffle(rest_of_distances)
        for wd_i, (target_width, target_distance) in enumerate(widths_and_distances):
            if wd_i % len(rest_of_distances) == 0:
                print('Script.TargetWidth,' + json.dumps({
                    'target_width': target_width,
                }))

            movements = list()
            rect = [(0, minimum_distance), (target_distance, 0), (0, -minimum_distance), (-target_distance, 0)]
            swap = [1] + [-1, 1] * repetitions
            for (dx, dy) in rect:
                for factor in swap:
                    movements.append((dx * factor, dy * factor))
            print('Script.BeginBlock,' + json.dumps({
                'run_length': len(movements) + 1,
                'distance': target_distance,
            }))
            sys.stdout.flush()

            for i, (dx, dy) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
                print('Script.ShowTargetIndicator,' + json.dumps({
                    'id': i,
                    'x': our_screen_resolution[0] * 0.5 + target_distance * 0.5 * dx,
                    'y': our_screen_resolution[1] * 0.5 + minimum_distance * 0.5 * dy,
                    'w': target_width,
                    'h': target_width,
                }))

            x = our_screen_resolution[0] * 0.5 - target_distance * 0.5
            y = our_screen_resolution[1] * 0.5 - minimum_distance * 0.5
            print('Script.ShowDiscardedTarget,' + json.dumps({
                'x': x,
                'y': y,
                'w': target_width,
                'h': target_width,
                'distance': 0.0,
            }))

            for i, (dx, dy) in enumerate(movements):
                last_x, last_y, x, y = x, y, x + dx, y + dy
                print('Script.ShowTarget,' + json.dumps({
                    'x': x,
                    'y': y,
                    'w': target_width,
                    'h': target_width,
                    'distance': euclidean_distance(x, y, last_x, last_y),
                }))

            for i in range(4):
                print('Script.HideTargetIndicator,' + json.dumps({
                    'id': i
                }))
            sys.stdout.flush()


def do_aligned_rectangular(blocks, repetitions):
    target_distances = our_target_distances_in_pixels * repetitions
    print('Script.Start,' + json.dumps({
        'multiple_modes': 1,
        'target_distances': our_target_distances_in_pixels,
        'target_widths': our_target_widths_in_pixels,
    }))
    random.shuffle(interaction_modes)
    for mode in interaction_modes:
        print('Script.InteractionMode,' + json.dumps({
            'mode': mode,
        }))
        our_target_distances_in_pixels.sort();
        minimum_distance, rest_of_distances = our_target_distances_in_pixels[0], our_target_distances_in_pixels[1:];
        widths_and_distances = []
        standing_position_index = 0
        for i in range(blocks):
            # For the first runs of the first len(our_standing_positions) blocks,
            # do the longest distance first, as that will
            # encourage people to use the distance interaction technique from
            # the outset.
            if i < len(our_standing_positions):
                rest_of_distances = sorted(rest_of_distances)[::-1]
            else:
                random.shuffle(rest_of_distances)
            random.shuffle(our_target_widths_in_pixels)
            for width in our_target_widths_in_pixels:
                for distance in rest_of_distances:
                    widths_and_distances.append((width, distance, our_standing_positions[standing_position_index]))
                random.shuffle(rest_of_distances)
            standing_position_index = (standing_position_index + 1) % len(our_standing_positions)
        for wd_i, (target_width, target_distance, standing_position) in enumerate(widths_and_distances):
            if wd_i % (len(rest_of_distances) * len(our_target_widths_in_pixels)) == 0:
                print('Script.BeginBigBlock,' + json.dumps({
                    'standing_x': standing_position
                }))
            if wd_i % len(rest_of_distances) == 0:
                print('Script.TargetWidth,' + json.dumps({
                    'target_width': target_width,
                }))

            side = 1 if standing_position < our_screen_resolution[0] / 2 else -1
            target_positions = [
                (standing_position, our_screen_resolution[1] * 0.5 - minimum_distance * 0.5),
                (standing_position, our_screen_resolution[1] * 0.5 + minimum_distance * 0.5),
                (standing_position + target_distance * side, our_screen_resolution[1] * 0.5 + minimum_distance * 0.5),
                (standing_position + target_distance * side, our_screen_resolution[1] * 0.5 - minimum_distance * 0.5)
            ];

            index_changes = ([1] + [-1, 1] * repetitions) * 4
            print('Script.BeginBlock,' + json.dumps({
                'run_length': len(index_changes) + 1,
                'distance': target_distance,
            }))
            sys.stdout.flush()

            for i, (x, y) in enumerate(target_positions):
                print('Script.ShowTargetIndicator,' + json.dumps({
                    'id': i,
                    'x': x,
                    'y': y,
                    'w': target_width,
                    'h': target_width,
                }))

            print('Script.ShowDiscardedTarget,' + json.dumps({
                'x': target_positions[0][0],
                'y': target_positions[0][1],
                'w': target_width,
                'h': target_width,
                'distance': 0.0,
            }))
            target_position_index = 0
            for change in index_changes:
                last_x = target_positions[target_position_index][0]
                last_y = target_positions[target_position_index][1]
                target_position_index = (target_position_index + change) % len(target_positions)
                x = target_positions[target_position_index][0]
                y = target_positions[target_position_index][1]
                print('Script.ShowTarget,' + json.dumps({
                    'x': x,
                    'y': y,
                    'w': target_width,
                    'h': target_width,
                    'distance': euclidean_distance(last_x, last_y, x, y),
                }))

            for i in range(4):
                print('Script.HideTargetIndicator,' + json.dumps({
                    'id': i
                }))
            sys.stdout.flush()


def euclidean_distance(x1, y1, x2, y2):
    return math.sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)


def target_is_onscreen_and_not_on_seam(x, y, w):
    return target_is_onscreen(x, y, w) and not target_is_on_seam(x, y, w)


def target_is_onscreen(x, y, w):
    return x - (w / 2) > our_screen_border and \
           x + (w / 2) < our_screen_resolution[0] - our_screen_border and \
           y - (w / 2) > our_screen_border and \
           y + (w / 2) < our_screen_resolution[1] - our_screen_border


def target_is_on_seam(x, y, w):
    return any(x - w < seam and x + w > seam for seam in our_screen_vertical_seams) or \
           any(y - w < seam and y + w > seam for seam in our_screen_horizontal_seams)


def generate_width_block(w, target_distances):
    while True:
        target_positions = list()
        initial_target_position_x = random.randrange(int(our_screen_border + w),
                                                     int(our_screen_resolution[0] - our_screen_border - w))
        initial_target_position_y = random.randrange(int(our_screen_border + w),
                                                     int(our_screen_resolution[1] - our_screen_border - w))
        target_positions.append((initial_target_position_x, initial_target_position_y, 0))
        random.shuffle(target_distances)
        for distance in target_distances:
            last_target_x, last_target_y, _ = target_positions[-1]
            random.shuffle(angle_candidates)
            for angle_candidate in angle_candidates:
                angle_radians = angle_candidate / 180.0 * math.pi
                angle_sin = math.sin(angle_radians)
                angle_cos = math.cos(angle_radians)
                new_target_position_x = last_target_x + angle_sin * distance
                new_target_position_y = last_target_y + angle_cos * distance
                if target_is_onscreen_and_not_on_seam(new_target_position_x, new_target_position_y, w):
                    target_positions.append((new_target_position_x, new_target_position_y, distance))
                    break
                else:
                    continue
            else:
                # We got to the end of the angle candidates without hitting a
                # break, so no angle candidate was valid. This target distance
                # cannot be fulfilled.
                break
        else:
            # We got to the end of the target distances without breaking out of
            # the loop. This means every target distance was achieved. We have
            # a valid width block.
            return target_positions


if __name__ == '__main__':
    main()
