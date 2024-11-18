#VERSION: 1.00
# AUTHORS: 
#   Hung Nguyen (hungnt.code@proton.me)
# LICENSING INFORMATION

from html.parser import HTMLParser
from urllib.parse import urlencode
from helpers import download_file, retrieve_url
from novaprinter import prettyPrinter
# some other imports if necessary
import json
from datetime import datetime

class torrust(object):
    """
    `url`, `name`, `supported_categories` should be static variables of the engine_name class,
     otherwise qbt won't install the plugin.

    `url`: The URL of the search engine.
    `name`: The name of the search engine, spaces and special characters are allowed here.
    `supported_categories`: What categories are supported by the search engine and their corresponding id,
    possible categories are ('all', 'anime', 'books', 'games', 'movies', 'music', 'pictures', 'software', 'tv').
    """

    url = 'https://index.torrust-demo.com'
    name = 'Torrust'

    # Torrust categories API: https://index.torrust-demo.com/api/v1/category
    # Map qBittorrent categories to Torrust categories
    supported_categories = {
        'all': '',
        'movies': 'movies',
        'tv': 'tv shows',
        'games': 'games',
        'music': 'music',
        'software': 'software',
        'books': ['audiobook', 'paper']
    }

    def __init__(self):
        """
        Some initialization
        """

    def download_torrent(self, info):
        """
        Providing this function is optional.
        It can however be interesting to provide your own torrent download
        implementation in case the search engine in question does not allow
        traditional downloads (for example, cookie-based download).
        """
        print(download_file(info))

    # DO NOT CHANGE the name and parameters of this function
    # This function will be the one called by nova2.py
    def search(self, what, cat='all'):
        """
        Here you can do what you want to get the result from the search engine website.
        Everytime you parse a result line, store it in a dictionary
        and call the prettyPrint(your_dict) function.

        `what` is a string with the search tokens, already escaped (e.g. "Ubuntu+Linux")
        `cat` is the name of a search category in ('all', 'anime', 'books', 'games', 'movies', 'music', 'pictures', 'software', 'tv')
        """
        base_url = 'https://index.torrust-demo.com/api/v1/torrents?%s'
        category_value = self.supported_categories[cat]
        categories = ','.join(category_value) if isinstance(category_value, list) else category_value
        params = {'search': what, 'categories': categories}
        response = retrieve_url(base_url % urlencode(params))
        
        json_data = json.loads(response)
        results = json_data['data']['results']
        
        for result in results:
            info_hash = result['info_hash']
            torrent_info = {
                'link': f"magnet:?xt=urn:btih:{info_hash}",
                'name': result['title'],
                'size': result['file_size'], 
                'seeds': result['seeders'],
                'leech': result['leechers'],
                'engine_url': self.url,
                'desc_link': f"{self.url}/torrent/{info_hash}",
                'pub_date': int(datetime.strptime(result['date_uploaded'], '%Y-%m-%d %H:%M:%S').timestamp())
            }
            prettyPrinter(torrent_info)