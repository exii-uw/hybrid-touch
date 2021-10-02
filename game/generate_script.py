#!/usr/bin/env python3

import sys
import math
import json
import random
import itertools

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
# our_target_distances_in_centimetres = [100, 183.33, 266.66, 350] # 4 metres is just too damn far.
# our_target_widths_in_centimetres = [3.38, (3.38 + 6.77) / 2, 6.77, 6.77 * 1.5] # TOO DAMN SMALL
# our_target_widths_in_centimetres = [5.08, 10.16]
# our_target_distances_in_pixels = [our_screen_pixel_density * d for d in our_target_distances_in_centimetres]
# our_target_widths_in_pixels = [our_screen_pixel_density * w for w in our_target_widths_in_centimetres]
# our_standing_positions = [our_screen_resolution[0] / 8, our_screen_resolution[0] * 7 / 8]


enemy_types = ['Enemy.Cannon', 'Enemy.BlackHole', 'Enemy.Shield']
# angle_candidates = list(range(720))


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Generate a script for running a trial.')
    parser.add_argument('--blocks', help='number of blocks', type=int, default=2)
    parser.add_argument('--repetitions', help='number of waves of each enemy type per block', type=int, default=2)
    parser.add_argument('--enemies', help='number of enemies of the main type per wave', type=int, default=12)
    parser.add_argument('--sub-enemies', help='number of enemies of the opposite type per wave', type=int, default=4)
    parser.add_argument('--flank-enemies', help='number of enemies of a different type per wave', type=int, default=2)
    parser.add_argument('--enemy-speed', help='speed of enemies in cm/s', type=float, default=1.0)
    parser.add_argument('--sub-enemy-speed', help='speed of sub-enemies in cm/s', type=float, default=0.9)
    parser.add_argument('--flank-enemy-speed', help='speed of flank enemies in cm/s', type=float, default=1.1)
    parser.add_argument('--spawn-angle', help='angle range in which enemies are spawned in deg', type=float, default=40)
    parser.add_argument('--enemy-spawn-rate', help='number of enemy spawns per side per second',
            type=float, default=1.0)
    parser.add_argument('--sub-enemy-spawn-rate', help='number of enemy spawns per side per second',
            type=float, default=1.0)
    parser.add_argument('--flank-enemy-spawn-rate', help='number of enemy spawns per side per second',
            type=float, default=1.0)
    parser.add_argument('--randomness', help='random permutation amount', type=float, default=2.0)
    arguments = parser.parse_args()

    do_trial(arguments)


def do_trial(arguments):
    '''
    Create a single trial with the number of blocks and repetitions specified.

    Blocks separate an invasion of all enemy types; the trial will stop and show
    a dialog window between each block to make sure the participants are ready
    to continue. Repetitions are how many times an enemy type will spawn from
    *both* sides of the screen; with one repetition, each enemy type will spawn
    once from the left side, and once from the right side.

    During each wave, the left side will spawn primarily one enemy type, while
    the right side will spawn primarily a different enemy type. Intermixed in
    these will be a small number of the other side's enemy type (to encourage
    the use of distance interaction techniques even if the appropriate enemy
    for your tool is within your workspace), as well as a small number of
    a third enemy type (to encourage users to switch tools).
    '''

    enemy_count = arguments.enemies + arguments.sub_enemies + arguments.flank_enemies
    left_angles = [(i - enemy_count * 0.5) / enemy_count * arguments.spawn_angle for i in range(enemy_count)]
    right_angles = [i + 180.0 for i in left_angles]
    angle_variance = left_angles[1] - left_angles[0]
    enemy_type_list = list(zip(enemy_types, enemy_types[1:] + enemy_types[:1])) +\
                      list(zip(enemy_types[1:] + enemy_types[:1], enemy_types))
    total_waves = arguments.repetitions * len(enemy_types)
    enemy_type_list_cursor = 0
    print('Script.Start,' + json.dumps({
        'enemy_types': enemy_types,
        'arguments': vars(arguments),
    }))
    for block_index in range(arguments.blocks):
        print('Script.BeginBlock,' + json.dumps({
            'index': block_index,
        }))
        for wave_index in range(total_waves):
            type_a, type_b = enemy_type_list[enemy_type_list_cursor]
            type_c = enemy_type_list[enemy_type_list_cursor]
            for i in range(1, len(enemy_type_list)):
                type_c = enemy_type_list[(enemy_type_list_cursor + i) % len(enemy_type_list)][0]
                if type_c not in {type_a, type_b}:
                    break
            print('Script.BeginWave,' + json.dumps({
                'left_type': type_a,
                'right_type': type_b,
                'flank_type': type_c,
            }))
            enemy_type_list_cursor = (enemy_type_list_cursor + 1) % len(enemy_type_list);
            left_enemy_lists = [[(type_a, arguments.enemy_speed, arguments.enemy_spawn_rate)
                                   for i in range(arguments.enemies)],
                                [(type_b, arguments.sub_enemy_speed, arguments.sub_enemy_spawn_rate)
                                   for i in range(arguments.sub_enemies)]]
            right_enemy_lists = [[(type_b, arguments.enemy_speed, arguments.enemy_spawn_rate)
                                    for i in range(arguments.enemies)],
                                 [(type_a, arguments.sub_enemy_speed, arguments.sub_enemy_spawn_rate)
                                    for i in range(arguments.sub_enemies)]]
            flank_enemies = [(type_c, arguments.flank_enemy_speed, arguments.flank_enemy_spawn_rate)
                                   for i in range(arguments.flank_enemies)]
            random.shuffle(left_enemy_lists)
            random.shuffle(right_enemy_lists)
            left_enemies = sum(left_enemy_lists, [])
            right_enemies = sum(right_enemy_lists, [])
            if random.random() < 0.5:
                left_angles = left_angles[::-1]
            if random.random() < 0.5:
                right_angles = right_angles[::-1]
            shuffle(left_enemies, arguments.randomness)
            shuffle(right_enemies, arguments.randomness)
            interleave(left_enemies, flank_enemies)
            interleave(right_enemies, flank_enemies)
            shuffle(left_angles, arguments.randomness)
            shuffle(right_angles, arguments.randomness)
            for (left, left_speed, left_spawn_rate), (right, right_speed, right_spawn_rate), left_angle, right_angle\
                    in zip(left_enemies, right_enemies, left_angles, right_angles):
                for type, speed, angle, spawn_rate, side in\
                        ((left, left_speed, left_angle, left_spawn_rate, 'Side.Left'),
                         (right, right_speed, right_angle, right_spawn_rate, 'Side.Right')):
                    print('Script.SpawnEnemy,' + json.dumps({
                        'side': side,
                        'speed': speed,
                        'angle': angle + (random.random() * 2.0 - 1.0) * angle_variance,
                        'spawnTime': 1.0 / spawn_rate,
                        'type': type,
                    }))
            print('Script.EndWave,' + json.dumps({
                'left_type': type_a,
                'right_type': type_b,
                'flank_type': type_c,
            }))
        print('Script.EndBlock,' + json.dumps({
            'index': block_index,
        }))
    print('Script.End,{}')


def shuffle(list, randomness):
    '''Shuffle the given list by an amount proportional to the given randomness value.
    A value of 1.0 means that there will be one swapping of adjacent elements per number
    of elements in the list.'''
    swaps = int(len(list) * randomness)
    for i in range(swaps):
        index = random.randrange(0, len(list) - 1)
        list[index], list[index + 1] = list[index + 1], list[index]


def interleave(list, insert):
    '''Mutate the given list by inserting the values given in the second list at random
    positions.'''
    for element in insert:
        index = random.randrange(0, len(list) + 1)
        list.insert(index, element)


if __name__ == '__main__':
    main()
