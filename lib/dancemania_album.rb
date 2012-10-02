require 'open-uri'
require 'nokogiri'
require 'taglib'

class DancemaniaAlbum
  DANCEMANIA_URL = 'http://www.emimusic.jp/dancemania/dancemania/'
  @@ALBUMS ||= (
    doc = Nokogiri::HTML(open(DANCEMANIA_URL))
    titles = doc.css('p.cdttl').map{|a| a.children.text.split(/\s|\u3000/).join(' ') }
    links = doc.css('p.cdttl + a').map{|a| a.attributes['href'].value }
    Hash[*titles.zip(links).flatten]
  )

  def initialize(album, opts)
    url = if /(?:\w+:\/\/)|^www\./i.match(album)
      album
    else
      normalize_href(@@ALBUMS.inject({}){|h,(k,v)| h[k.downcase] = v; h }[album.downcase])
    end
    raise DancemaniaAlbum::AlbumNotFound if url.nil? || url.empty?
    @tracks = {}
    doc = Nokogiri::HTML(Nokogiri::HTML.parse(open(url).read).to_html) # ridiculous
    @album_title = opts[:album_title] || doc.css('p.cd_ttl').first.text.
      gsub(/\u300e|\u300f/, '').split(/\s|\u3000/).join(' ')
    @art = open(normalize_href doc.css('#disc img').first.attributes['src'].value)
    @album_artist = opts[:artist_name] || "Dancemania"
    doc.css('#M-contents p.tracklist').each do |tl|
      info = /(\d+)\.\s*(.*)(?:\/|\uff0f)(.*)?/.match(tl.text.strip)
      if info
        track, artist, title = info[1..-1].map{|x| x.strip }
        if /\uff0f/.match(tl.text.strip) # this is crazy
          title = artist
          artist = @album_artist
        end
        @tracks[track.to_i] = { :artist => artist, :title => title }
      end
    end
    fix_insane_special_cases
  end

  def preview
    n = 0
    Dir.glob("*.[mM][pP]3") do |song|
      tracknum = (n += 1)
      puts "filename: #{song}"
      puts "track number: #{tracknum}"
      puts "track title: #{@tracks[tracknum][:title]}"
      puts "track artist: #{@tracks[tracknum][:artist]}"
      puts "album artist: #{@album_artist}"
      puts "new filename: #{generate_filename(song, tracknum)}"
      puts "----------"
    end
    true
  end

  def tag
    n = 0
    Dir.glob("*.[mM][pP]3"){|song| tag_track(song, (n += 1)) }
    true
  end

  def rename
    n = 0
    Dir.glob("*.[mM][pP]3"){|song| rename_track(song, (n += 1)) }
    true
  end

  def tag_and_rename
    tag and rename
  end

  def tag_track(filename, tracknum)
    artist, title = [@tracks[tracknum][:artist], @tracks[tracknum][:title]]
    TagLib::MPEG::File.open(filename) do |f|
      tag = f.id3v2_tag
      tag.track = tracknum
      tag.title = title
      tag.artist = artist
      tag.album = @album_title

      tpe2 = TagLib::ID3v2::TextIdentificationFrame.new('TPE2',
        TagLib::String::UTF8)
      tpe2.text = @album_artist
      tag.add_frame(tpe2)

      apic = TagLib::ID3v2::AttachedPictureFrame.new
      apic.mime_type = @art.content_type
      apic.description = "Cover"
      apic.type = TagLib::ID3v2::AttachedPictureFrame::FrontCover
      apic.picture = @art.read
      tag.add_frame(apic)

      f.save
    end
  end

  def rename_track(filename, num)
    File.rename(filename, generate_filename(filename, num))
  end

  class AlbumNotFound < Exception
    def message
      "Album not found. Be sure you entered the name correctly."
    end
  end

  private

  def generate_filename(filename, num)
    artist, title = [@tracks[num][:artist], @tracks[num][:title]]
    n = num < 10 ? "0#{num.to_s}" : num.to_s
    new_name = "#{n} - #{artist} - #{title}.mp3"
    bad_chars = /<|>|:|"|\/|\\|\||\?|\*/
    new_name.gsub(bad_chars,'').split(' ').join(' ')
  end

  def normalize_href(href)
    href[0].chr == '/' ? "http://www.emimusic.jp#{href}" : DANCEMANIA_URL + href
  end

  def fix_insane_special_cases
    @album_title = @album_title[0..-3] if @album_title[-2..-1] == ' -' # Captain's Best
  end
end