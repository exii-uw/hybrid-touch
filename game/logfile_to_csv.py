#!/usr/bin/env python3

'''
The format of an event file is very simple: Each line of the file should
contain three comma-separated fields. The first is a timestamp in
milliseconds, the second is an identifier for what type of event it is,
and the third is a JSON string containing any arbitrary attributes of
the event type.
'''

import re
import os
import csv
import sys
import glob
import json
import math
import datetime
import itertools
import collections
from operator import itemgetter, attrgetter


screen_size = (413, 117)
screen_resolution = (7680, 2160)
pixel_to_real = screen_size[0] / screen_resolution[0]


# For extracting attributes from the filename of a trial record.
attrpair_re = re.compile(r'(\w+)=(\w+)')

# For parsing the format of the date and time listed in the trial record.
datetime_re = re.compile(r'(?P<year>\d+)-(?P<month>\d+)-(?P<day>\d+) (?P<hour>\d+)-(?P<minute>\d+)-(?P<second>\d+)')

# These events are not yielded or stored. For performance reasons -- these
# aren't that helpful to analysis and they take up the majority of the log
# file.
ignore_events = {'Hybrid.DeadZoneChanged',
                 'Input.RawTouchDown',
                 'Input.RawTouchUp',
                 'Input.RawTouchMove',
                 'Input.TouchDown',
                 'Input.TouchUp',
                 'Input.TouchMove',
                 'Trial.WeaponMoved'}


class Enemy(object):
    __slots__ = 'id type x y radius spawn_x spawn_y spawn_time distance_travelled'.split()
class Cursor(object):
    __slots__ = 'participant x y spawn_x spawn_y spawn_time distance_travelled'.split()
class Workspace(object):
    __slots__ = 'participant x y'.split()


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Analyze a few files.')
    parser.add_argument('directory', type=str, nargs=1, help='the directory containing the files to analyze '
            '(or a single file)')
    parser.add_argument('--kill-data-csv', action='store_true', help='create a csv of enemy data for all trials')
    parser.add_argument('--touch-data-csv', action='store_true', help='create a csv of touch data for all trials')
    arguments = parser.parse_args()

    writer = csv.writer(sys.stdout)
    row_keys = []
    if arguments.kill_data_csv:
        row_keys = ['RowIndex',
                    'TrialIndex',
                    'EnemyId',
                    'EnemyType',
                    'EnemyScriptType',
                    'EnemyX_cm',
                    'EnemyY_cm',
                    'EnemyLiveTime_ms',
                    'EnemyDistanceTravelled_cm',
                    'BlockIndex',
                    'WaveIndex',
                    'WithinWaveIndex',
                    'ParticipantIdKilled',
                    'RealParticipantIdKilled',
                    'ParticipantOnSameSideIndicator',
                    'UsedCursorIndicator',
                    'CursorMoveDistanceTravelled_cm',
                    'CursorMoveDisplacement_cm',
                    'EnemyDistanceFromWorkspaceCentre_cm',
                    'EnemyDistanceFromCursorSpawn_cm',
                    'CannonBlastId',
                    'BlackHoleEncircleId',
                    'CooperativeIndicator']
    global ignore_events
    if arguments.touch_data_csv:
        row_keys = ['RowIndex', 'TrialIndex', 'ParticipantId', 'RealParticipantId', 'TouchX_cm', 'TouchY_cm', 'Heat_ms',
                'RelativeModeIndicator', 'CooperativeModeIndicator']
        ignore_events = {}
    writer.writerow(row_keys)
    row_index = -1
    trials = list()
    if os.path.isdir(arguments.directory[0]):
        for filename in sorted(glob.glob(os.path.join(arguments.directory[0], '*.csv'))):
            trials.append(Trial(filename))
    else:
        trials.append(Trial(arguments.directory[0]))

    static_workspace_mid_gutter_px = 580
    movable_workspace_radius_px = 512

    for (trial_index, trial) in enumerate(trials):
        cooperative = None
        script_path = next(value for identifier, value in trial.iter_attributes() if identifier == 'script')
        block_index = -1
        wave_index = -1
        within_wave_index = -1
        participant_id_by_identifier = {}
        cursors = {}
        workspaces = {}
        enemies = {}
        hackish_participant_id_counter = -1
        true_participant_id_counter = -1
        cannon_blast_id = -1
        last_cannon_blast_timestamp = None
        black_hole_encircle_id = -1
        last_black_hole_encircle_timestamp = None
        touch_coding = {}
        touch_id_next_unique_index = {}

        if trial.attributes.get('movableWorkspaces', False):
            def in_workspace_px(workspace, x, y):
                dx = workspace.x - x * pixel_to_real
                dy = workspace.y - y * pixel_to_real
                r = movable_workspace_radius_px * pixel_to_real
                return dx * dx + dy * dy <= r * r
        else:
            def in_workspace_px(workspace, x, y):
                if workspace.x < screen_size[0] / 2:
                    return x < screen_resolution[0] / 2 - static_workspace_mid_gutter_px / 2
                else:
                    return x > screen_resolution[0] / 2 + static_workspace_mid_gutter_px / 2
        cooperative = bool(trial.attributes['cooperative'])

        waves_from_script = (json.loads(data) for (event, separator, data) in
                (line.partition(',') for line in open('script/script.csv', 'r')) if event == 'Script.BeginWave')

        for event_index, event in enumerate(trial.events):
            try:
                if event.identifier == 'Trial.DamageTakenChanged':
                    # We originally didn't record which participant corresponded to which workspace.
                    # But we can still recover this data using the DamageTakenChanged events, which
                    # iterated over the workspaces from left-to-right.
                    participant = event.data['participant']
                    if participant not in participant_id_by_identifier:
                        hackish_participant_id_counter += 1
                        participant_id_by_identifier[participant] = hackish_participant_id_counter
                        workspace = Workspace()
                        workspace.participant = participant
                        workspace.x = screen_size[0] * 0.25 * (1 + hackish_participant_id_counter * 2)
                        workspace.y = screen_size[1] * 0.5
                        workspaces[participant] = workspace
                elif event.identifier == 'Trial.WorkspaceInitialized':
                    # This overrides the DamageTakenChanged workspace hack.
                    true_participant_id_counter += 1
                    participant_id_by_identifier[event.data['participant']] = true_participant_id_counter
                    workspace = Workspace()
                    workspace.participant = event.data['participant']
                    workspace.x = event.data['x'] * pixel_to_real
                    workspace.y = event.data['y'] * pixel_to_real
                    workspaces[event.data['participant']] = workspace
                elif event.identifier == 'Trial.WorkspaceMoved':
                    workspace = workspaces[event.data['participant']]
                    workspace.x = event.data['x'] * pixel_to_real
                    workspace.y = event.data['y'] * pixel_to_real
                elif event.identifier == 'Hybrid.CursorSpawned':
                    assert event.data['participant'] not in cursors
                    cursor = Cursor()
                    cursor.participant = event.data['participant']
                    cursor.x = event.data['x'] * pixel_to_real
                    cursor.y = event.data['y'] * pixel_to_real
                    cursor.spawn_time = event.timestamp
                    cursor.spawn_x = cursor.x
                    cursor.spawn_y = cursor.y
                    cursor.distance_travelled = 0
                    cursors[event.data['participant']] = cursor
                elif event.identifier == 'Hybrid.CursorMoved':
                    cursor = cursors[event.data['participant']]
                    cursor.distance_travelled += distance(cursor.x - event.data['x'] * pixel_to_real,
                                                          cursor.y - event.data['y'] * pixel_to_real)
                    cursor.x = event.data['x'] * pixel_to_real
                    cursor.y = event.data['y'] * pixel_to_real
                elif event.identifier == 'Hybrid.CursorDespawned':
                    assert event.data['participant'] in cursors
                    del cursors[event.data['participant']]
                elif event.identifier == 'Trial.BeginBlock':
                    block_index += 1
                elif event.identifier == 'Trial.BeginWave':
                    wave_index = event.data['waveNumber']
                    within_wave_index = -1
                    data = next(waves_from_script)
                    left_type = data['left_type']
                    right_type = data['right_type']
                    flank_type = data['flank_type']
                elif event.identifier == 'Trial.EnemySpawned':
                    assert event.data['id'] not in enemies
                    enemy = Enemy()
                    enemy.id = event.data['id']
                    enemy.x = event.data['x'] * pixel_to_real
                    enemy.y = event.data['y'] * pixel_to_real
                    enemy.radius = event.data['r'] * pixel_to_real
                    enemy.type = event.data['type']
                    enemy.spawn_x = enemy.x
                    enemy.spawn_y = enemy.y
                    enemy.spawn_time = event.timestamp
                    enemy.distance_travelled = 0
                    enemies[enemy.id] = enemy
                elif event.identifier == 'Trial.EnemyMoved':
                    # Enemy movement is still triggered after enemies are killed,
                    # because they are removed lazily at the end of the frame. So
                    # we will see one extra EnemyMoved event after an enemy has
                    # been hit.
                    if event.data['id'] not in enemies:
                        continue
                    enemy = enemies[event.data['id']]
                    enemy.distance_travelled += distance(enemy.x - event.data['x'] * pixel_to_real,
                                                         enemy.y - event.data['y'] * pixel_to_real)
                    enemy.x = event.data['x'] * pixel_to_real
                    enemy.y = event.data['y'] * pixel_to_real
                elif event.identifier == 'Trial.EnemyHit':
                    assert event.data['id'] in enemies
                    if arguments.kill_data_csv:
                        row_data = [None] * len(row_keys)
                        row_index += 1
                        within_wave_index += 1
                        workspace = workspaces[event.data['participant']]
                        enemy = enemies[event.data['id']]
                        cursor = cursors.get(event.data['participant'], None)
                        # We assume that there won't be more than a
                        # single millisecond between concurrent enemy eliminations
                        # in a single defeat event.
                        if event.data['type'] == 'Enemy.Cannon':
                            if event.timestamp != last_cannon_blast_timestamp and \
                               event.timestamp - 1 != last_cannon_blast_timestamp:
                                cannon_blast_id += 1
                            last_cannon_blast_timestamp = event.timestamp
                        if event.data['type'] == 'Enemy.BlackHole':
                            if event.timestamp != last_black_hole_encircle_timestamp and \
                               event.timestamp - 1 != last_black_hole_encircle_timestamp:
                                black_hole_encircle_id += 1
                            last_black_hole_encircle_timestamp = event.timestamp
                        row_data[row_keys.index('RowIndex')] = row_index
                        row_data[row_keys.index('TrialIndex')] = trial_index
                        row_data[row_keys.index('EnemyId')] = enemy.id
                        row_data[row_keys.index('EnemyType')] = enemy.type
                        row_data[row_keys.index('EnemyScriptType')] = 'Main'\
                                if (event.data['type'] == left_type and event.data['x'] < screen_resolution[0] * 0.5)\
                                or (event.data['type'] == right_type and event.data['x'] >= screen_resolution[0] * 0.5)\
                                else 'Sub'\
                                if (event.data['type'] == right_type and event.data['x'] < screen_resolution[0] * 0.5)\
                                or (event.data['type'] == left_type and event.data['x'] >= screen_resolution[0] * 0.5)\
                                else 'Flank'
                        row_data[row_keys.index('EnemyX_cm')] = event.data['x'] * pixel_to_real
                        row_data[row_keys.index('EnemyY_cm')] = event.data['y'] * pixel_to_real
                        row_data[row_keys.index('EnemyLiveTime_ms')] = event.timestamp - enemy.spawn_time
                        row_data[row_keys.index('EnemyDistanceTravelled_cm')] = enemy.distance_travelled
                        row_data[row_keys.index('BlockIndex')] = block_index
                        row_data[row_keys.index('WaveIndex')] = wave_index
                        row_data[row_keys.index('WithinWaveIndex')] = within_wave_index
                        row_data[row_keys.index('ParticipantIdKilled')] = \
                            participant_id_by_identifier[event.data['participant']]
                        row_data[row_keys.index('RealParticipantIdKilled')] = event.data['participant']
                        row_data[row_keys.index('ParticipantOnSameSideIndicator')] = int(not (
                            (workspace.x                     < (screen_size[0] * 0.5)) ^ # XOR
                            (event.data['x'] * pixel_to_real < (screen_size[0] * 0.5))))
                        row_data[row_keys.index('UsedCursorIndicator')] = int(cursor is not None)
                        row_data[row_keys.index('CursorMoveDistanceTravelled_cm')] = (cursor.distance_travelled
                                if cursor is not None else 0)
                        row_data[row_keys.index('CursorMoveDisplacement_cm')] = (
                                distance(cursor.x - cursor.spawn_x, cursor.y - cursor.spawn_y)
                                if cursor is not None else 0)
                        row_data[row_keys.index('EnemyDistanceFromWorkspaceCentre_cm')] = distance(
                                enemy.x - workspace.x, enemy.y - workspace.y)
                        row_data[row_keys.index('EnemyDistanceFromCursorSpawn_cm')] = (distance(
                                enemy.x - cursor.x, enemy.y - cursor.y)
                                if cursor is not None else 0)
                        row_data[row_keys.index('CannonBlastId')] = (cannon_blast_id
                                if event.data['type'] == 'Enemy.Cannon' else 0)
                        row_data[row_keys.index('BlackHoleEncircleId')] = (black_hole_encircle_id
                                if event.data['type'] == 'Enemy.BlackHole' else 0)
                        row_data[row_keys.index('CooperativeIndicator')] = int(cooperative)
                        writer.writerow(row_data)
                    del enemies[event.data['id']]
                elif event.identifier == 'Trial.EnemyCollide':
                    assert event.data['id'] in enemies
                    del enemies[event.data['id']]
                elif event.identifier == 'Input.RawTouchDown':
                    if event.data['id'] in touch_id_next_unique_index:
                        touch_id_next_unique_index[event.data['id']] += 1
                    else:
                        touch_id_next_unique_index[event.data['id']] = 0
                    uid = touch_id_next_unique_index[event.data['id']]
                    for participant, workspace in workspaces.items():
                        if in_workspace_px(workspace, event.data['x'], event.data['y']):
                            touch_coding[event.data['id'], uid] = participant
                            break
                elif event.identifier == 'Input.RawTouchMove':
                    uid = touch_id_next_unique_index[event.data['id']]
                    if (event.data['id'], uid) not in touch_coding:
                        for participant, workspace in workspaces.items():
                            if in_workspace_px(workspace, event.data['x'], event.data['y']):
                                touch_coding[event.data['id'], uid] = participant
                                break

            except:
                print("In file", trial.filename, "line", event.line_number, file=sys.stderr)
                raise
            sys.stdout.flush()

        participant_from_id = {x: y for (y, x) in participant_id_by_identifier.items()}
        if arguments.touch_data_csv:
            # We make two passes over the data, so that we can code touches that
            # are only coded after they've moved somewhat.
            touch_id_current_unique_index = {}
            touch_time = {}
            cursors = {}
            for event_index, event in enumerate(trial.events):
                try:
                    if event.identifier == 'Input.RawTouchDown':
                        if event.data['id'] in touch_id_current_unique_index:
                            touch_id_current_unique_index[event.data['id']] += 1
                        else:
                            touch_id_current_unique_index[event.data['id']] = 0
                        uid = touch_id_current_unique_index[event.data['id']]
                        touch_time[event.data['id'], uid] = event.timestamp
                    elif event.identifier == 'Input.RawTouchMove':
                        uid = touch_id_current_unique_index[event.data['id']]
                        participant = touch_coding.get((event.data['id'], uid), None)
                        heat = event.timestamp - touch_time[event.data['id'], uid]
                        touch_time[event.data['id'], uid] = event.timestamp
                        row_data = [None] * len(row_keys)
                        row_index += 1
                        participant_id = participant_id_by_identifier.get(participant, -1)
                        row_data[row_keys.index('RowIndex')] = row_index
                        row_data[row_keys.index('TrialIndex')] = trial_index
                        row_data[row_keys.index('ParticipantId')] = participant_id
                        row_data[row_keys.index('RealParticipantId')] = participant
                        row_data[row_keys.index('TouchX_cm')] = event.data['x'] * pixel_to_real
                        row_data[row_keys.index('TouchY_cm')] = event.data['y'] * pixel_to_real
                        row_data[row_keys.index('Heat_ms')] = heat
                        row_data[row_keys.index('RelativeModeIndicator')] = int(participant in cursors)
                        row_data[row_keys.index('CooperativeModeIndicator')] = int(cooperative)
                        writer.writerow(row_data)
                    elif event.identifier == 'Hybrid.CursorSpawned':
                        assert event.data['participant'] not in cursors
                        cursor = Cursor()
                        cursor.participant = event.data['participant']
                        cursor.x = event.data['x'] * pixel_to_real
                        cursor.y = event.data['y'] * pixel_to_real
                        cursor.spawn_time = event.timestamp
                        cursor.spawn_x = cursor.x
                        cursor.spawn_y = cursor.y
                        cursor.distance_travelled = 0
                        cursors[event.data['participant']] = cursor
                    elif event.identifier == 'Hybrid.CursorMoved':
                        cursor = cursors[event.data['participant']]
                        cursor.distance_travelled += distance(cursor.x - event.data['x'] * pixel_to_real,
                                                              cursor.y - event.data['y'] * pixel_to_real)
                        cursor.x = event.data['x'] * pixel_to_real
                        cursor.y = event.data['y'] * pixel_to_real
                    elif event.identifier == 'Hybrid.CursorDespawned':
                        assert event.data['participant'] in cursors
                        del cursors[event.data['participant']]
                except:
                    print("In file", trial.filename, "line", event.line_number, file=sys.stderr)
                    raise


def distance(x, y):
    return (x * x + y * y) ** 0.5


def parse_datetime(string):
    attrs = datetime_re.match(string).groupdict()
    for k, v in attrs.items():
        attrs[k] = int(v)
        if k == 'year':
            if attrs[k] < 100:
                if attrs[k] < 69:
                    attrs[k] += 2000
                else:
                    attrs[k] += 1900
    return datetime.datetime(**attrs)


Event = collections.namedtuple('Event', 'timestamp identifier data line_number')


class Trial(object):
    __slots__ = map(str.strip, '''
        filename
        attributes
        producer
        lazy_events
        last_timestamp
    '''.split())
    def __init__(self, filename):
        self.filename = filename
        self.attributes = dict()
        for match in attrpair_re.finditer(filename):
            self.attributes[match.group(1).lower()] = match.group(2)
        self.producer = Trial.event_producer(filename)
        first_event = next(self.producer)
        assert first_event.identifier == 'System.Startup'
        first_event.data['time'] = parse_datetime(first_event.data['time'])
        self.last_timestamp = first_event.timestamp
        for key, value in first_event.data.items():
            self.attributes[key] = value
    @staticmethod
    def event_producer(filename):
        with open(filename) as file:
            for index, line in enumerate(file):
                timestamp, _, rest = line.partition(',')
                identifier, _, data = rest.partition(',')
                identifier = identifier.strip()
                if identifier in ignore_events:
                    continue
                try:
                    event = Event(int(timestamp), identifier, json.loads(data), index + 1)
                except ValueError:
                    print("In file", filename, "line", index + 1, file=sys.stderr)
                    raise
                yield event
    def iter_attributes(self):
        return self.attributes.items()
    def attribute_string(self):
        return ', '.join(str(a) + ': ' + str(b) for (a, b) in sorted(self.iter_attributes(), key=itemgetter(0)))
    def __iter__(self):
        return self
    def __next__(self):
        next_value = next(self.producer)
        assert next_value.timestamp >= self.last_timestamp
        self.last_timestamp = next_value.timestamp
        return next_value
    @property
    def events(self):
        try:
            return self.lazy_events
        except AttributeError:
            self.lazy_events = list(self)
            return self.lazy_events



def stddev(values):
    values = list(values)
    if not values:
        return 0.0
    mean = sum(list(values)) / len(values)
    stddev = (sum((value - mean) ** 2 for value in values) / (len(values) - 1)) ** 0.5 if len(values) > 1 else 0
    return stddev


if __name__ == '__main__':
    main()
