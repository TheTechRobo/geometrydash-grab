###################
###GEOMETRY DASH###
###GRAB SCRIPTS####
###################

# Based heavily off of ArchiveTeam/urls-grab

import seesaw
from seesaw.config import realize, NumberConfigValue
from seesaw.project import *
from seesaw.tracker import *
from seesaw.util import *
from seesaw.pipeline import Pipeline
from seesaw.externalprocess import WgetDownload
from seesaw.item import ItemInterpolation, ItemValue
from seesaw.task import SimpleTask, LimitConcurrent

import hashlib
import shutil
import socket
import sys
import json
import time

project = Project(
  title = "Geometry Dash",
  project_html = """
    <h2>Geometry Dash</h2>
    <p>Time to archive Geometry Dash?</p>
  """,
)

###########################################################################
# The version number of this pipeline definition.
#
# Update this each time you make a non-cosmetic change.
# It will be added to the WARC files and reported to the tracker.
VERSION = '20220917.01'
#USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.183 Safari/537.36'
TRACKER_ID = 'geometrytrash'
TRACKER_HOST = '172.17.0.1:8501'

WGET_AT = find_executable(
    'Wget+AT',
    [
	    'GNU Wget 1.20.3-at.20211001.01'
	],
    [
        './wget-at',
        '/home/warrior/data/wget-at'
    ]
)

if not WGET_AT:
    raise Exception('No usable Wget+At found.')

class CheckIP(SimpleTask):
    def __init__(self):
        SimpleTask.__init__(self, 'CheckIP')
        self._counter = 0

    def process(self, item):
        # NEW for 2014! Check if we are behind firewall/proxy

        if self._counter <= 0:
            item.log_output('Checking IP address.')
            ip_set = set()

            ip_set.add(socket.gethostbyname('twitter.com'))
            #ip_set.add(socket.gethostbyname('facebook.com'))
            ip_set.add(socket.gethostbyname('youtube.com'))
            ip_set.add(socket.gethostbyname('microsoft.com'))
            ip_set.add(socket.gethostbyname('icanhas.cheezburger.com'))
            ip_set.add(socket.gethostbyname('archiveteam.org'))

            if len(ip_set) != 5:
                item.log_output('Got IP addresses: {0}'.format(ip_set))
                item.log_output(
                    'Are you behind a firewall/proxy? That is a big no-no!')
                raise Exception(
                    'Are you behind a firewall/proxy? That is a big no-no!')

        # Check only occasionally
        if self._counter <= 0:
            self._counter = 10
        else:
            self._counter -= 1



class PrepareDirectories(SimpleTask):
    def __init__(self, warc_prefix):
        SimpleTask.__init__(self, 'PrepareDirectories')
        self.warc_prefix = warc_prefix

    def process(self, item):
        item_name = item['item_name']
        item_name_hash = hashlib.sha1(item_name.encode('utf8')).hexdigest()
        escaped_item_name = item_name_hash
        dirname = '/'.join((item['data_dir'], escaped_item_name))

        if os.path.isdir(dirname):
            shutil.rmtree(dirname)

        os.makedirs(dirname)

        item['item_dir'] = dirname
        item['warc_file_base'] = '-'.join([
            self.warc_prefix,
            item_name_hash,
            time.strftime('%Y%m%d-%H%M%S')
        ])

        open('%(item_dir)s/%(warc_file_base)s.warc.gz' % item, 'w').close()
        open('%(item_dir)s/%(warc_file_base)s_retry-urls.txt' % item, 'w').close()

def get_hash(filename):
    with open(filename, 'rb') as in_file:
        return hashlib.sha1(in_file.read()).hexdigest()

CWD = os.getcwd()
PIPELINE_SHA1 = get_hash(os.path.join(CWD, 'pipeline.py'))
LUA_SHA1 = get_hash(os.path.join(CWD, 'grab.lua'))
GMD_LUA_SHA1 = get_hash(os.path.join(CWD, 'gmd.lua'))

def stats_id_function(item):
    d = {
        'pipeline_hash': PIPELINE_SHA1,
        'lua_hash': LUA_SHA1,
        'gmd_lua_hash': GMD_LUA_SHA1,
        'python_version': sys.version,
    }

    return d

class MoveFiles(SimpleTask):
    def __init__(self):
        SimpleTask.__init__(self, 'MoveFiles')

    def process(self, item):
        item["ts"] = time.time()
        item["dd"] = item["data_dir"].lstrip("grab/data/")
        shutil.move('%(item_dir)s/' % item,
            '/%(data_dir)s/_%(ts)s/' % item)

class AwfulBackfeed(SimpleTask):
    def __init__(self):
        SimpleTask.__init__(self, 'AwfulBackfeed')

    def process(self, item):
        with open('%(item_dir)s/new_items' % item) as file:
            new_items = file.read()

class WgetArgs(object):
    def realize(self, item):
        wget_args = [
            'timeout', '1d',
            WGET_AT,
            '-v',
            '--content-on-error',
            '--lua-script', 'grab.lua',
            '-o', ItemInterpolation('%(item_dir)s/wget.log'),
            #'--no-check-certificate',
            '--output-document', ItemInterpolation('%(item_dir)s/wget.tmp'),
            '--truncate-output',
            '-e', 'robots=off',
            '--rotate-dns',
            '--timeout', '10',
            '-w', '2',
            '--random-wait',
            '--tries', '10',
            '--span-hosts',
            '--waitretry', '5000',
            '--warc-file', ItemInterpolation('%(item_dir)s/%(warc_file_base)s'),
            '--warc-header', 'operator: TheTechRobo <thetechrobo@protonmail.ch>',
            '--warc-header', json.dumps(stats_id_function(item)),
            '--warc-header', 'x-wget-at-project-version: ' + VERSION,
            '--warc-header', 'x-wget-at-project-name: ' + TRACKER_ID,
            '--warc-dedup-url-agnostic',
            '--header', 'Contact: Discord TheTechRobo#7420',
            '--header', 'Connection: keep-alive',
            '-U', ""
        ]

        item['item_name_newline'] = item['item_name'].replace('\0', '\n')
        item_urls = []
        custom_items = {}

        for item_name in item['item_name'].split('\0'):
            wget_args.extend(['--warc-header', 'x-wget-at-project-item-name: '+item_name])
            wget_args.append('item-name://'+item_name)
            item_urls.append('http://thetechrobo.ca:1337/'+item_name)
            wget_args.append('http://thetechrobo.ca:1337/'+item_name)

        item['item_urls'] = item_urls
        item['custom_items'] = json.dumps(custom_items)

        if 'bind_address' in globals():
            wget_args.extend(['--bind-address', globals()['bind_address']])
            print('')
            print('*** Wget will bind address at {0} ***'.format(
                globals()['bind_address']))
            print('')

        return realize(wget_args, item)

pipeline = Pipeline(
        CheckIP(),
        GetItemFromTracker('http://{}/{}'
            .format(TRACKER_HOST, TRACKER_ID),
            downloader, VERSION),
        PrepareDirectories(warc_prefix='gmd'),
        WgetDownload(
            WgetArgs(),
            max_tries=1,
            accept_on_exit_code=[0, 4, 8],
            env={
                'item_dir': ItemValue('item_dir'),
                'item_name': ItemValue('item_name_newline'),
                'custom_items': ItemValue('custom_items'),
                'warc_file_base': ItemValue('warc_file_base')
            }
        ),
        PrepareStatsForTracker(
            defaults={'downloader': downloader, 'version': VERSION},
            file_groups={
                'data': [
                    ItemInterpolation('%(item_dir)s/%(warc_file_base)s.warc.gz')
                ]
            },
            id_function=stats_id_function,
            ),
        MoveFiles(),
        LimitConcurrent(NumberConfigValue(min=1, max=20, default='2',
            name='shared:rsync_threads', title='Rsync threads',
            description='The maximum number of concurrent uploads.'),
            UploadWithTracker(
                'http://%s/%s' % (TRACKER_HOST, TRACKER_ID),
                downloader=downloader,
                version=VERSION,
                files=[
                    ItemInterpolation('%(data_dir)s/_%(ts)s/%(warc_file_base)s.warc.gz')
                ],
                rsync_target_source_path=ItemInterpolation('%(data_dir)s/'),
                rsync_extra_args=[
                    '--recursive',
                    '--partial',
                    '--partial-dir', '.rsync-tmp',
                    '--min-size', '1',
                    '--no-compress',
                    '--compress-level', '0'
                ]
            ),
        ),
        SendDoneToTracker(
            tracker_url='http://%s/%s' % (TRACKER_HOST, TRACKER_ID),
            stats=ItemValue('stats')
            )
        )
