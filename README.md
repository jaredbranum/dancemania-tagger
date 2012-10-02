dancemania-tagger
=================

Scrapes emimusic.jp to fix ID3v2 tags for Dancemania albums

## Setup

Install taglib (OS X / Linux; for Windows just be sure to use Ruby 1.9)
 - APT: `sudo apt-get install libtag1-dev`
 - yum: `sudo yum install taglib-devel`
 - Homebrew: `brew install taglib`
 - MacPorts: `sudo port install taglib`

Clone the project and install required gems:

    git clone git@github.com:jaredbranum/dancemania-tagger.git
    cd dancemania-tagger && bundle install
Add `dancemania-tagger` to your path (optional):

    export PATH=$PATH:`pwd`/bin

Run `dancemania-tagger` from a directory containg a Dancemania album. By default, this will tag and rename the MP3s.

## Usage

    dancemania-tagger [album] [--album-title title] [--artist-name artist] [--help] [--preview] [--rename-only] [--tag-only]

`album`: The name of the album (e.g. "Dancemania SPEED G") or URL for that album (e.g. <http://www.emimusic.jp/dancemania/dancemania/disco/tocp64222.htm>).

`--album-title title`: The name of the album (used to override the value from the album page).


`--artist-name artist`: The album artist name (defaults to "Dancemania").

`--help`: Displays help. No files will be renamed or tagged when this argument is passed.

`--preview`: Prints out what tags and filenames would be used to tag and rename. No files will be renamed or tagged when this argument is passed.

`--rename-only`: MP3s will be renamed, but tags will be unchanged.

`--tag-only`: MP3s will be tagged, but filenames will be unchanged.