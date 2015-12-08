require 'open-uri'
require 'nokogiri'
require 'taglib'

class DancemaniaAlbum
  DANCEMANIA_URL = 'http://microsites.universal-music.co.jp/dancemania/dancemania/'
  @@ALBUMS ||= (
    doc = Nokogiri::HTML(open(DANCEMANIA_URL))
    titles = doc.css('p.cdttl').map{|a| a.children.text.split(/(?:\s|\u3000)+/).join(' ') }
    links = doc.css('p.cdttl + a').map{|a| a.attributes['href'].value }
    Hash[*titles.zip(links).flatten]
  )

  def initialize(album, opts={})
    begin
      @url = if /(?:\w+:\/\/)|^www\./i.match(album)
        album
      else
        fix_href(Hash[@@ALBUMS.map{|k,v| [k.downcase, v]}][album.downcase])
      end
    rescue
    end
    raise DancemaniaAlbum::AlbumNotFound if @url.nil? || @url.empty?
    @tracks = {}
    doc = Nokogiri::HTML(Nokogiri::HTML.parse(open(@url).read).to_html) # ridiculous
    @album_title = opts[:album_title] || doc.css("p:contains('\u300e')").first.
      text.gsub(/\u300e|\u300f|\u3000|\r|\n/, ' ').split(' ').join(' ')
    @art = open(fix_href doc.css('#disc img').first.attributes['src'].value)
    @album_artist = opts[:artist_name] || "Dancemania"
    doc.css('#M-contents p.tracklist').each do |tl|
      info = /(\d+)\.\s*([^\/|\uff0f]*)(?:(?:\/|\uff0f)(.*))?/.match(
        tl.text.gsub(/\u3000|\r|\n/, ' ').strip.split(' ').join(' '))
      if info
        track, artist, title = info[1..-1].map{|x| x.strip unless x.nil? }
        @tracks[track.to_i] = { :artist => artist, :title => title }
      end
    end
    fix_insane_special_cases
  end

  def preview
    n = 0
    puts "album title: #{@album_title}"
    puts "album artist: #{@album_artist}"
    Dir.glob("*.[mM][pP]3") do |song|
      tracknum = (n += 1)
      puts "----------"
      puts "filename: #{song}"
      puts "track number: #{tracknum}"
      puts "track title: #{@tracks[tracknum][:title]}"
      puts "track artist: #{@tracks[tracknum][:artist]}"
      puts "new filename: #{generate_filename(song, tracknum)}"
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
    bad_chars = /<|>|:|"|\/|\\|\||\?/
    new_name.gsub('*','-').gsub(bad_chars,'').split(' ').join(' ')
  end

  def fix_href(href)
    href[0].chr == '/' ? "http://www.emimusic.jp#{href}" : DANCEMANIA_URL + href
  end

  def fix_insane_special_cases
    if /tocp4002/.match(@url) # Dancemania 1
      @album_title = "Dancemania 1"
    end

    if /tocp64200/.match(@url) # Dancemania EX 2
      @tracks[5] = { :artist => "LADYBIRD", :title => "DANGEROUS TO ME" }
    end

    if /tocp64229/.match(@url) # Dancemania EX 5
      @album_title = "Dancemania EX 5"
      @tracks[5]  = { :artist => "CAPTAIN JACK", :title => "EARLY IN THE MORNING (we like the captain)" }
      @tracks[6]  = { :artist => "SCATMAN JOHN", :title => "SCATMAN 2003" }
      @tracks[7]  = { :artist => "FRIDAY NIGHT POSSE", :title => "KISS THIS (Voodoo & Serano Remix)" }
      @tracks[8]  = { :artist => "AQUAGEN", :title => "HARD TO SAY I'M SORRY" }
      @tracks[9]  = { :artist => "BTH", :title => "DOMINGO DANCING" }
      @tracks[10] = { :artist => "X-TREME", :title => "TAKE THE RECORD, DADDY!" }
      @tracks[11] = { :artist => "DJ ROMA feat. MC YOUNG MAN", :title => "MC YOUNG MAN" }
      @tracks[12] = { :artist => "AMEN UK", :title => "PASSION (Paul Masterson Club Mix)" }
      @tracks[13] = { :artist => "LA LUNA", :title => "FALLIN' (Radio Edit)" }
      @tracks[14] = { :artist => "KATE RYAN", :title => "SCREAM FOR MORE (Radio Edit)" }
      @tracks[15] = { :artist => "ULTRABEAT", :title => "PRETTY GREEN EYES (CJ Stone Remix)" }
      @tracks[16] = { :artist => "LOUD FORCE", :title => "ROCK'N ROLL" }
      @tracks[17] = { :artist => "NEXT AGE", :title => "PARADISE" }
      @tracks[18] = { :artist => "C-LOUD", :title => "FUNKY TOWN" }
    end

    if /(tocp64250)|(tocp64262)|(tocp64266)/.match(@url) # Dancemania EX 7, EX 8, EX 9
      @tracks.each {|k,v| @tracks[k] = { :title => v[:artist], :artist => v[:title] } }
    end

    if /tocp64262/.match(@url) # Dancemania EX 8
      @tracks[18][:title] = "ROCK FOR LIFE"
    end

    if /tocp64266/.match(@url) # Dancemania EX 9
      @tracks[9] = { :artist => @tracks[9][:title], :title => @tracks[9][:artist] }
      @tracks[12][:artist] = "THE SHAPESHIFTERS"
    end

    if /tocp64071/.match(@url) # Dancemania SUMMERS 3
      @album_title = "Dancemania SUMMERS 3"
    end

    if /tocp64122/.match(@url) # Dancemania SUMMERS 2001
      @tracks[16][:title] = "BRASIL OVER ZURICH"
      @tracks[17][:title] = "SWEETEST DAY OF MAY (Club Gospel Mix)"
    end

    if /tocp64222/.match(@url) # Dancemania SPEED G
      @tracks[3][:title] = "MR. DABADA (Skyrock Speed Mix)"
      @tracks[22][:title] = "LET THE BEAT CONTROL YOUR BODY (B4 ZA BEAT SPEED MIX)"
    end

    if /tocp64232/.match(@url) # Dancemania SPEED G2
      @album_title = "Dancemania SPEED G2"
      @tracks[22][:title] = "DON'T EVEN TRY IT"
    end

    if /tocp64253/.match(@url) # Dancemania SPEED G3
      @tracks.each {|k,v| @tracks[k] = { :title => v[:artist], :artist => v[:title] } }
      @tracks[13] = { :artist => "ROSE", :title => "I'VE NEVER BEEN TO ME" }
      @tracks[14] = { :artist => "JUDY CRYSTAL", :title => "YOU CAN'T HURRY LOVE" }
    end

    if /tocp64264/.match(@url) # Dancemania SPEED G4
      @album_title = "Dancemania SPEED G4"
      @tracks.each {|k,v| @tracks[k] = { :title => v[:artist], :artist => v[:title] } }
      @tracks[2][:artist] = "CJ CREW feat.THE FIRELIGHTERS SHOWGROUP"
      @tracks[7][:title] = "9 TO 5 MORNING TRAIN"
      @tracks[8][:title] = "DIP IT LOW (Eurotrance Speedo Mix)"
      @tracks[18][:title] = "DON'T TELL ME(Super Speedotrance)"
      @tracks[21][:artist] = "DJ BRISK & HAM"
      @tracks[24][:artist] = "IN EFFECT & IMPACT"
    end

    if /tocp64283/.match(@url) # Dancemania SPEED G5
      @tracks.each {|k,v| @tracks[k] = { :title => v[:artist], :artist => v[:title] } }
      @tracks[1][:artist] = "DJ SPEEDO feat. RAFFA"
      @tracks[5][:title] = "TAKE A RIDE(Gammer remix)"
      @tracks[20][:artist] = "BRISK & HAM"
      @tracks[21][:artist] = "BRISK & HAM"
    end

    if /tocp64231/.match(@url) # Christmas SPEED
      @tracks.each{|k,v| @tracks[k] = { :title =>
        /([\w\s'!\uff01\-]+).*$/.match(v[:artist])[1].strip.gsub("\uff01", "!")
      }}
      @tracks[1][:artist]  = 'ROSE'
      @tracks[2][:artist]  = 'SPEED ALL STARS'
      @tracks[3][:artist]  = 'HARDCORE SYNTH ORCHESTRA'
      @tracks[4][:artist]  = 'CJ CREW featuring BUNGA BUNGA'
      @tracks[5][:artist]  = 'MAZERATI'
      @tracks[6][:artist]  = 'DJ JAXX'
      @tracks[7][:artist]  = 'ROSE & JOHN'
      @tracks[8][:artist]  = 'DJ ELASTOPLAST'
      @tracks[9][:artist]  = 'TERRY AND THE PHYSICIST'
      @tracks[10][:artist] = 'NANCY AND THE BOYS'
      @tracks[11][:artist] = 'CHI K MUNKI'
      @tracks[12][:artist] = 'CJ CREW featuring MC BYGGLZ'
      @tracks[13][:artist] = 'NANCY AND THE BOYS featuring TONI'
      @tracks[14][:artist] = 'EL FEZ'
      @tracks[15][:artist] = 'SPEEDOMASTER'
      @tracks[16][:artist] = 'DJ SPEEDO feat. WILDSIDE'
      @tracks[17][:artist] = 'JOHN DESIRE'
      @tracks[18][:artist] = 'VIOLENT STRING ENSAMBLE'
      @tracks[19][:artist] = 'MC F 40'
      @tracks[20][:artist] = 'KK feat. MANU'
    end

    if /tocp64189/.match(@url) # classical SPEED
      @tracks.each{|k,v| @tracks[k] = { :title =>
        (v[:artist].include?('[') ? /\[(.*)\]/ : /(.*)(?:\s?\(.*)/).match(v[:artist])[1].strip
      }}
      @tracks[1][:artist]  = 'MC F 40'
      @tracks[2][:artist]  = 'SPEEDORCHESTRA'
      @tracks[3][:artist]  = 'KK FEAT MANU'
      @tracks[4][:artist]  = 'ROSE'
      @tracks[5][:artist]  = 'HARDCORE SYNTH ORCHESTRA'
      @tracks[6][:artist]  = 'BLUE VENICE'
      @tracks[7][:artist]  = 'CJ CREW'
      @tracks[8][:artist]  = 'CJ CREW'
      @tracks[9][:artist]  = 'CJ CREW featuring LILLA D'
      @tracks[10][:artist] = 'CJ CREW'
      @tracks[11][:artist] = 'CJ CREW'
      @tracks[12][:artist] = 'S.N.A.H.'
      @tracks[13][:artist] = 'VIOLENT STRING ENSAMBLE'
      @tracks[14][:artist] = 'VENTURA'
      @tracks[15][:artist] = 'BUS STOP'
      @tracks[16][:artist] = 'DJ KAMBEL VS MC MAGIKA'
      @tracks[17][:artist] = 'MR. VIB-E-RATOR'
      @tracks[18][:artist] = 'S&K'
      @tracks[19][:artist] = 'MAZERATI'
      @tracks[20][:artist] = 'HARDCORE SYNTH ORCHESTRA + JONNY MITRAGLIA'

      @tracks[15][:title] = 'KICK THE CAN (Hyper KCP Mix)'
    end

    @album_title = @album_title[0..-3] if @album_title[-2..-1] == ' -' # Captain's Best
    # E-Rotic Megamix, Best of E-Rotic, and Captain's Best
    if /(tocp64084)|(tocp64137)|(tocp64126)/.match(@url)
      @tracks.each do |k,v|
        @tracks[k] = { :title => v[:artist], :artist => @album_artist }
      end
    end
  end
end
