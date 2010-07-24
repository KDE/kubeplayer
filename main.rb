#!/usr/bin/env ruby1.9
# kate: remove-trailing-space on; replace-trailing-space-save on; indent-width 2; indent-mode ruby; syntax ruby; space-indent on;

require 'korundum4'
require 'phonon'
require 'kio'
require 'rubygems'
require 'json'
require 'net/http'
require 'cgi'
require 'pp'

# The class video is an abstract class to download, hold and organize all
# important data. It gets subclassed by the VideoProvider classes.
#
# The VideoProvider class is expected to reimplement #accept? and others
#
module Kube

  UserRole = Qt::UserRole.to_i
  ItemTypeRole, VideoRole, ActiveTrackRole = *(UserRole...(UserRole+3))
  ItemTypeVideo,ItemTypeShowMore = 1,2

class Video < Qt::Object
  # contains the list with all known providers
  @@provider = []
  def self.register_provider aProvider
    @@provider.push aProvider
  end

  # contains the list with all videos
  @@videoCollection = Hash.new do |collection,kurl|
    if kurl.valid?
      video =  self.get_type kurl
      collection[kurl] = video unless video.nil?
    end
  end

  #:call-seq:
  #  accept?(KDE::Url) => bool
  #
  # this function has to be reimplemented by its subclasses
  def self.accept? kurl
    false
  end

  #:call-seq:
  # new(KDE::Url) => Opject of a subclass of Video
  #
  # you get a subclass back or nil
  def self.get_type kurl
    @@provider.each do |aProvider|
      video = aProvider.get_type kurl
      return video unless video.nil?
    end
    return nil
  end

  def self.get kurl
    @@videoCollection[kurl]
  end

=begin
  def == aVideo
    self.url == aVideo.url
  end
=end


  # get the title of the video
  attr_accessor :title


  signals :got_thumbnail, 'got_video_url(QVariant)'

  #:call-seq:
  # thumbnail_url() => KDE::Url
  #
  # get the url to the image of the thumbnail
  attr_reader :thumbnail_url
  def thumbnail_url= kurl
    if kurl.valid?
      @thumbnail_url = kurl
      job = KIO::storedGet kurl , KIO::NoReload, KIO::HideProgressInfo
      connect(job, SIGNAL( 'result( KJob* )' )) do |aJob|
        if aJob.error == 0
          @thumbnail = Qt::Image.from_data aJob.data
          emit got_thumbnail
        else
          qDebug 'Warning: loading thumbnail failed for' + @url + ' : ' + @thumbnail_url
        end
      end
    end
  end

  def thumbnail_job_result aJob
  end

  def video_url= kurl
    @video_url = kurl if kurl.valid?
  end

  #:call-seq:
  # title() => KDE::Url
  #
  # get the internet page of this video
  attr_reader :url

  #:call-seq:
  # title() => string
  #
  # get the author of this video
  attr_accessor :author


  # QDateTime
  attr_accessor :published

  #:call-seq:
  # duration() => Float
  #
  # get the duration in s
  attr_accessor :duration

  #:method: getVideoInfo(QVariant)
  #slots 'get_video_info()'

  attr_reader :thumbnail

  attr_reader :video_url

  def initialize kurl
    super()
    @url = kurl
    @title = nil
    @thumbnail_url = nil
    @thumbnail = nil
    @video_url = nil
    @author = nil
    @published = Qt::DateTime.new # dateTime # FIXME
    @duration = nil
  end

  def to_s
    @title or '[unbenannt]'
  end

   # FIXME (this implementation doesn't work to protect the constructor
  protected :initialize
end

class YoutubeVideo < Video

  @@validUrl = Qt::RegExp.new 'http://www\.youtube\.com/watch\?v=[^&]+.*'
  INFO_REQUEST  = 'http://www.youtube.com/get_video_info?&video_id=%s&el=embedded&ps=default&eurl=&gl=US&hl=en'
  VIDEO_URL     = 'http://www.youtube.com/watch'
  HEADER        = {
    'cookies' => 'none'
  }

  #:call-seq:
  #  accept?(KDE::Url) => bool
  def self.accept? kurl
    @@validUrl.exact_match kurl.url
  end

  def self.get_type kurl
    self.new kurl if self.accept? kurl
  end

#   def get_video_info qvariant = nil
#     video_url
#
#     emit got_video_info
#   end

  def initialize kurl
    super(kurl)
  end


  # http://eduviews.com/portal/getting-youtube-video-url
  def request_video_url
    unless @video_url == false
      @video_url = false

      infoRequestJob = KIO::storedGet @url , KIO::NoReload, KIO::HideProgressInfo
      HEADER.each do |key, val|
        infoRequestJob.addMetaData key, val
      end
      connect(infoRequestJob, SIGNAL( 'result( KJob* )' )) do |aJob|
        match = /^\s*var swfConfig = (.+);$/.match aJob.data.data
        @fmtUrlMap = Hash[*JSON.parse(match[1])['args']['fmt_url_map'].split(',').map{ |val| val = /\|/.match(val); [val.pre_match.to_i, val.post_match.gsub(/ip=0\.0\.0\.0/,'ip=91.0.0.0')] }.flatten]
        pp @fmtUrlMap
        @video_url = KDE::Url.new @fmtUrlMap.max[1]

        emit got_video_url(Qt::Variant.from_value(self))
      end
    end
    # emit got_video_url(Qt::Variant.from_value(self))
  end
end
=begin
        @token = metaInfo[:token]
        # @id = metaInfo[:video_id]
	metaInfo[:fmt_url_map] = KDE::Url::fromPercentEncoding(Qt::ByteArray.new '5%7Chttp%3A%2F%2Fv18.lscache7.c.youtube.com%2Fvideoplayback%3Fip%3D0.0.0.0%26sparams%3Did%252Cexpire%252Cip%252Cipbits%252Citag%252Calgorithm%252Cburst%252Cfactor%252Coc%253AU0dXRVBLVl9FSkNNN19IRVpJ%26fexp%3D907114%252C901807%26algorithm%3Dthrottle-factor%26itag%3D35%26ipbits%3D0%26burst%3D40%26sver%3D3%26expire%3D1280008800%26key%3Dyt1%26signature%3D8FEDA1F8E55CE9B9619771F56DBA47177F050459.991F2D20457A443E757A43D92F4863AAC3C48F91%26factor%3D1.25%26id%3D06cdf7a1fed8e492%2C34%7Chttp%3A%2F%2Fv4.lscache7.c.youtube.com%2Fvideoplayback%3Fip%3D0.0.0.0%26sparams%3Did%252Cexpire%252Cip%252Cipbits%252Citag%252Calgorithm%252Cburst%252Cfactor%252Coc%253AU0dXRVBLVl9FSkNNN19IRVpJ%26fexp%3D907114%252C901807%26algorithm%3Dthrottle-factor%26itag%3D34%26ipbits%3D0%26burst%3D40%26sver%3D3%26expire%3D1280008800%26key%3Dyt1%26signature%3D4EBA92F9E489B3589C42BB4FA1DCEB8B4E4615F2.50028543378A878D91170C9A3171C2F4EEA1519A%26factor%3D1.25%26id%3D06cdf7a1fed8e492%2C5%7Chttp%3A%2F%2Fv22.lscache8.c.youtube.com%2Fvideoplayback%3Fip%3D0.0.0.0%26sparams%3Did%252Cexpire%252Cip%252Cipbits%252Citag%252Calgorithm%252Cburst%252Cfactor%252Coc%253AU0dXRVBLVl9FSkNNN19IRVpJ%26fexp%3D907114%252C901807%26algorithm%3Dthrottle-factor%26itag%3D5%26ipbits%3D0%26burst%3D40%26sver%3D3%26expire%3D1280008800%26key%3Dyt1%26signature%3DAF2144EECC826813DA2AB26501259D86C769F984.01AB10ECFF13ED78E15F42E41CA7247A89231322%26factor%3D1.25%26id%3D06cdf7a1fed8e492')
        @fmtUrlMap = Hash[*metaInfo[:fmt_url_map].split(',').map{ |val| val = /\|/.match(val); [val.pre_match.to_i, val.post_match.gsub(/ip=0\.0\.0\.0/,'ip=91.0.0.0')] }.flatten]
	@video_url = KDE::Url.new @fmtUrlMap.max[1]
# 	@video_url.remove_query_item 'fexp'
	@video_url.remove_query_item 'ip'
	@video_url.add_query_item 'ip', '91.0.0.0'
	@video_url.remove_query_item 'ipbits'
	@video_url.add_query_item 'ipbits', '8'
# 	'%2Coc%3' bis &
# 	@video_url = KDE::Url.new 'http://v18.lscache7.c.youtube.com/videoplayback?sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor&fexp=907114&algorithm=throttle-factor&itag=35&burst=40&sver=3&expire=1280008800&key=yt1&signature=8FEDA1F8E55CE9B9619771F56DBA47177F050459.991F2D20457A443E757A43D92F4863AAC3C48F91&factor=1.25&id=06cdf7a1fed8e492&ip=91.0.0.0&ipbits=8'
# 	@video_url = KDE::Url.new 'http://v18.lscache7.c.youtube.com/videoplayback?sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor&fexp=907112&algorithm=throttle-factor&itag=35&burst=40&sver=3&expire=1280005200&key=yt1&signature=C10CB759157E664AC23DAA8BC834E9FE52C71490.86D4011BD99A183664350D2E5756965E12ABD419&factor=1.25&id=06cdf7a1fed8e492&ip=91.0.0.0&ipbits=8'
	pp  @video_url.url
	emit got_video_url(Qt::Variant.from_value(self))
	videoRequestJob = KIO::mimetype KDE::Url.new @fmtUrlMap.max[1]
        # videoRequestJob.addMetaData 'PropagateHttpHeader', 'true'
        connect(videoRequestJob, SIGNAL( 'result( KJob* )' )) do |aJob|
	  # aJob.queryMetaData 'HTTP-Headers'
          if /^video\//.match(aJob.mimetype)
	    @video_url = aJob.url
	    emit got_video_url @video_url
	  end
        end
=end

Video.register_provider YoutubeVideo

class VideoList < Qt::AbstractListModel

  slots :update_thumbnail
  signals 'active_row_changed(int)'
  signals 'play_this(QVariant)'

  attr_reader :videos

  def initialize videos = nil
    super()
    @videos = []
    @videos = videos unless videos.nil?
    @activeVideo = nil
    @activeRow = nil
    @searching = false
    @autostart = false
  end

  def searching?
    @searching
  end

  # inherited from Qt::AbstractListModel
  def data modelIndex, role
    puts __LINE__ if $DEBUG
    row = modelIndex.row
    if include? row
      video = @videos[row]
      case role
      when VideoRole then
        return Qt::Variant.from_value video
      when ActiveTrackRole then
        puts __LINE__ if $DEBUG
        return Qt::Variant.new(video == @activeVideo)
      when Qt::DisplayRole, Qt::StatusTipRole then
          puts __LINE__ if $DEBUG
          return Qt::Variant.new video.to_s
      end
    end
    puts __LINE__.to_s + " " + role.inspect if $DEBUG
    Qt::Variant.new
  end

  # inherited from Qt::AbstractListModel
  def row_count modelIndex
    @videos.size
  end
  alias :rowCount :row_count

  # inherited from Qt::AbstractListModel
  def column_count modelIndex = nil
    4
  end
  alias :columnCount :column_count

  # inherited from Qt::AbstractListModel
  def remove_rows position, rows, modelIndex
    begin_remove_rows Qt::ModelIndex.new, position, position+rows-1
    for row in (0...rows)
      @videos.delete_at row
    end
    end_remove_rows
    reurn true
  end
  alias :removeRows :remove_rows

  def include? row
    (0...@videos.size).include? row
  end

  def [] index
    @videos[index]
  end

  def active= row

    if include? row
      @activeRow = row
      @activeVideo = @videos[row]

      emit dataChanged(create_index(row, 0), create_index(row, column_count()-1))
      emit active_row_changed(row)
    else
      @activeRow = nil
      @activeVideo = nil
    end
  end

  def next_row
    nextRow = @activeRow + 1
    if include? nextRow
      nextRow
    end
  end

  def active_video
    @activeVideo
  end

  def push video
    connect video, SIGNAL(:got_thumbnail), self, SLOT(:update_thumbnail)
    connect(video, SIGNAL('got_video_url(QVariant)')) do |variant|
      emit play_this(variant)
    end

    begin_insert_rows Qt::ModelIndex.new, @videos.size, @videos.size
    @videos.push video
    end_insert_rows

    if @videos.size == 1 and @autostart
      self.active = 0
    end
  end

  def update_thumbnail
    video = sender()
    if video.class <= Video
      row = row_for_video video
      emit dataChanged(create_index(row, 0), create_index(row, column_count()-1))
    else
      qDebug 'Cannot get sender'
    end
  end


  #:call-seq: => int
  def row_for_video video
    @videos.index video
  end

  #:call-seq: => Qt::ModelIndex
  def index_for_video video
    create_index @videos.index(video), 0
  end

end

class VideoItemDelegate < Qt::StyledItemDelegate
  THUMBNAIL_SIZE = [120, 90]
  PADDING = 10

  def initialize parent

    super

    @boldFont = Qt::Font.new
    @boldFont.bold = true

    @smallerFont = Qt::Font.new
    @smallerFont.point_size = @smallerFont.point_size*0.85

    @smallerBoldFont = Qt::Font.new
    @smallerBoldFont.bold = true
    @smallerBoldFont.point_size = @smallerBoldFont.point_size*0.85

    fontInfo = Qt::FontInfo.new @smallerFont
    if fontInfo.pixel_size < 10
      @smallerFont.pixel_size = 10
      @smallerBoldFont.pixel_size = 10
    end

    @playIcon = Qt::Pixmap.new *THUMBNAIL_SIZE
    @playIcon.fill Qt::Color.new(Qt::transparent)
    painter = Qt::Painter.new @playIcon
    polygon = Qt::Polygon.new [Qt::Point.new(PADDING*4, PADDING*4), Qt::Point.new(THUMBNAIL_SIZE[0]-PADDING*4, THUMBNAIL_SIZE[1]/2), Qt::Point.new(PADDING*4, THUMBNAIL_SIZE[1]-PADDING*2)]
    # painter.render_hint = Qt::Painter::Antialiasing FIXME
    painter.brush = Qt::white
    pen = Qt::Pen.new
    pen.color = Qt::Color.new Qt::white
    pen.width = PADDING
    pen.join_style = Qt::RoundJoin
    pen.cap_style = Qt::RoundCap
    painter.pen = pen
    painter.draw_polygon polygon
  end

  def size_hint styleOptionViewItem, modelIndex
    Qt::Size.new 256, THUMBNAIL_SIZE[1]+1
  end
  alias :sizeHint :size_hint

  def paint painter, styleOptionViewItem, modelIndex
    puts __LINE__ if $DEBUG
    KDE::Application.style.drawPrimitive Qt::Style::PE_PanelItemViewItem, styleOptionViewItem, painter
    video = modelIndex.data(VideoRole).value
    paint_body painter, styleOptionViewItem, modelIndex
  end

  def paint_body painter, styleOptionViewItem, modelIndex
    painter.save
    painter.translate styleOptionViewItem.rect.top_left

    line = Qt::RectF.new 0, 0, styleOptionViewItem.rect.width, styleOptionViewItem.rect.height
    painter.clip_rect = line


    isActive = modelIndex.data(ActiveTrackRole).to_bool
    # isSelected = !((Qt::Style::State_Selected.to_i & styleOptionViewItem.state) > 0)

    # puts Qt::Style::State_Selected.inspect + ' ' + styleOptionViewItem.state.inspect
    # puts isActive.inspect + ' ' + isSelected.inspect
    if isActive
      paint_active_overlay painter, line.x, line.y, line.width, line.height
    end
    video = modelIndex.data(VideoRole).value
    #puts isSelected.inspect + " " + video.title

    unless video.thumbnail.nil?
      puts __LINE__ if $DEBUG
      painter.draw_image(Qt::Rect.new(0, 0, *THUMBNAIL_SIZE), video.thumbnail)
      puts __LINE__ if $DEBUG
      # paint_play_icon painter if isActive FIXME

      if video.duration > 3600 # more than 1 h
        format = 'h:mm:ss'
      else
        format = 'm:ss'
      end
      # draw_time painter, Qt::Time.new.add_secs(video.duration).to_string(format), line
    end

    painter.font = @boldFont if isActive
    fm = Qt::FontMetricsF.new painter.font
    boldMetrics = Qt::FontMetricsF.new @boldFont

    painter.pen = Qt::Pen.new(styleOptionViewItem.palette.brush(false ? Qt::Palette::HighlightedText : Qt::Palette::Text),0)

    title = video.title
    textBox = Qt::RectF.new line.adjusted PADDING+THUMBNAIL_SIZE[0], PADDING, -2*PADDING, -PADDING
    alignHints = (Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap)
    textBox = painter.boundingRect textBox, alignHints, title
    painter.draw_text textBox, alignHints, title

=begin
    painter.font = @smallerFont
    published = video.published.date.to_string Qt::DefaultLocaleShortDate
    publishedSize = Qt::SizeF.new(Qt::FontMetrics.new(painter.font).size(Qt::TextSingleLine, published))
    textLocation = Qt::PointF.new PADDING+THUMBNAIL_SIZE[0], PADDING*2+textBox.height
    publishedTextBox = Qt::RectF.new textLocation, publishedSize
    painter.draw_text publishedTextBox, alignHints, published

    painter.save
    painter.font = @smallerBoldFont

    painter.pen(Qt::Pen.new(styleOptionViewItem.palette.brush(Qt::Palette::Mid), 0)) if not isSelected and not isActive
    author = video.author
    authorSize = Qt::SizeF.new(Qt::FontMetrics.new(painter.font).size(Qt::TextSingleLine, author))
    textLocation.x = textLocation.x + publishedSize.width + PADDING
    authorTextBox = Qt::RectF.new textLocation, authorSize
    painter.draw_text authorTextBox, alignHints, author
    painter.restore

    painter.pen = styleOptionViewItem.palette.color(Qt::Palette::Midlight)
    painter.draw_line THUMBNAIL_SIZE[0], THUMBNAIL_SIZE[1], line.width, THUMBNAIL_SIZE[1]
    painter.pen = Qt::Color.new(Qt::black) unless video.thumbnail.nil?
    painter.draw_line 0, THUMBNAIL_SIZE[1], THUMBNAIL_SIZE[0]-1, THUMBNAIL_SIZE[1]
=end
    painter.restore
    puts __LINE__ if $DEBUG
  end

  def paint_active_overlay painter, x, y, w, h
    palette = Qt::Palette.new
    highlightColor = palette.color Qt::Palette::Highlight
    backgroundColor = palette.color Qt::Palette::Base

    animation = 0.25
    gradientRange = 16

    color2 = Qt::Color.fromHsv(highlightColor.hue,
                               (backgroundColor.saturation*(1-animation)+highlightColor.saturation*animation).to_i,
                               (backgroundColor.value*(1-animation)+highlightColor.value*animation).to_i)
    color1 = Qt::Color.fromHsv(color2.hue,[color2.saturation-gradientRange,0].max,[color2.value+gradientRange,255].min)
    rect = Qt::Rect.new x.to_i, y.to_i, w.to_i, h.to_i
    painter.save
    painter.pen = Qt::Pen.new(Qt::NoPen)
    linearGradient = Qt::LinearGradient.new 0, 0, 0, rect.height
    linearGradient.setColorAt(0, color1) # FIXME why not color_at= ?
    linearGradient.setColorAt(1, color2)
    painter.brush = Qt::Brush.new(linearGradient)
    painter.draw_rect rect
    painter.restore
  end


  def draw_time painter, time, line
    timePadding = 4
    textBox = painter.bounding_rect line, Qt::AlignLeft | Qt::AlignTop, time
    textBox.adjust 0, 0, timePadding, 0
    textBox.translate THUMBNAIL_SIZE[0]-textBox.width, THUMBNAIL_SIZE[1]-textBox.height

    painter.save
    painter.pen = Qt::Pen.new(Qt::NoPen)
    painter.brush = Qt::Brush.new(Qt::black)
    painter.opacity = 0.5
    painter.draw_rect textBox
    painter.restore

    painter.save
    painter.pen = Qt::Color.new(Qt::white)
    painter.draw_text textBox, Qt::AlignCenter, time
    painter.restore
  end

  def paint_play_icon painter
    painter.save
    painter.opacity = 0.5
    painter.draw_pixmap @playIcon.rect, @playIcon
    painter.restore
  end
end

class MainWindow < KDE::MainWindow

  slots 'toogleVolumeSlider(bool)', 'stateChanged(Phonon::State, Phonon::State)'

  def toogleVolumeSlider show
  end

  def stateChanged state, stateBefore
    case state
    when Phonon::PlayingState then
      @seekSlider.mediaObject = @videoPlayer.mediaObject
      @playPauseAction.checked = true
      @playPauseAction.enabled = true
    when Phonon::PausedState then
      @playPauseAction.checked = false
      @playPauseAction.enabled = true
    when Phonon::ErrorState then
      qDebug 'Phonon Error: ' + @videoPlayer.media_object.error_string + ' (' + @videoPlayer.media_object.error_type.to_s + ')'
    else
      @playPauseAction.enabled = false # unless state == Phonon::BufferingState
    end
  end

  def ini_phonon collection, menu, controlBar
    @videoPlayer = Phonon::VideoPlayer.new Phonon::VideoCategory, self
    volumeSlider = Phonon::VolumeSlider.new @videoPlayer.audioOutput, self
    seekSlider = Phonon::SeekSlider.new @videoPlayer.mediaObject, self
    @seekSlider = seekSlider

    # action play pause
    @playPauseAction = collection.add_action 'switch-pause', KDE::Action.new( self )
    @playPauseAction.checkable = true
    @playPauseAction.shortcut = KDE::Shortcut.new Qt::Key_Backspace, Qt::Key_MediaStop
    @playPauseAction.icon = KDE::Icon.new 'media-playback-pause'
    @playPauseAction.text = i18n '&Pause'
    @playPauseAction.enabled = false
    @playPauseAction.connect( SIGNAL('toggled(bool)') ) do |playing|
      if playing
        @videoPlayer.play
      else
        @videoPlayer.pause
      end
    end
    connect(@videoPlayer.mediaObject, SIGNAL('stateChanged(Phonon::State, Phonon::State)'), self, SLOT('stateChanged(Phonon::State, Phonon::State)'))
    menu.add_action @playPauseAction
    controlBar.add_action @playPauseAction

    # action previous
    action = collection.add_action 'controls-previous', KDE::Action.new( KDE::Icon.new( 'media-skip-backward' ), i18n( 'Previous' ), self )
    action.shortcut = KDE::Shortcut.new Qt::Key_PageUp, Qt::Key_MediaPrevious
    menu.add_action action
    controlBar.add_action action

    # action stop
    action = collection.add_action 'controls-stop', KDE::Action.new( KDE::Icon.new( 'media-playback-stop' ), i18n( 'Stop' ), self )
    action.shortcut = KDE::Shortcut.new Qt::Key_Backspace, Qt::Key_MediaStop
    action.connect( SIGNAL( :triggered ) ) do
      @videoPlayer.stop
    end
    menu.add_action action
    controlBar.add_action action

    # action forward
    action = collection.add_action 'controls-forward', KDE::Action.new( KDE::Icon.new( 'media-skip-forward' ), i18n( 'Forward' ), self )
    action.shortcut = KDE::Shortcut.new Qt::Key_PageDown, Qt::Key_MediaNext
    menu.add_action action
    controlBar.add_action action

    menu.add_separator

    # action volume mute
    audioMenu = KDE::Menu.new i18nc( 'Playback menu', 'Audio' ), self
    menu.add_menu audioMenu

    action = collection.add_action 'volume-mute', KDE::Action.new( KDE::Icon.new( 'player-volume' ), i18n( 'Mute Volume' ), self)
    action.checkable = true
    action.shortcut = KDE::Shortcut.new Qt::Key_M, Qt::Key_VolumeMute
    action.connect( SIGNAL('toggled(bool)') ) do |muted|
      action.set_icon KDE::Icon.new muted ? 'player-volume-muted' : 'player-volume' # audio-volume-muted' : 'audio-volume-medium'
      @videoPlayer.audioOutput.muted = muted
    end
    connect(volumeSlider.audioOutput, SIGNAL('mutedChanged(bool)'), action, SLOT('setChecked(bool)') )
    audioMenu.add_action action

    menu.add_separator

    action = collection.add_action 'volume-slider', KDE::Action.new( i18n( 'Volume Slider' ), self )
    action.default_widget = volumeSlider
    controlBar.add_action action

    action = collection.add_action 'seek-slider', KDE::Action.new( i18n( 'Position Slider' ), self )
    action.default_widget = seekSlider
    controlBar.add_action action

  end

  def initialize

    super

    #### prepare menus
    collection = KDE::ActionCollection.new self
    controlBar = KDE::ToolBar.new 'control_bar', self, Qt::BottomToolBarArea
    controlBar.tool_button_style = Qt::ToolButtonIconOnly

    menu = KDE::Menu.new i18n('&File'), self
    menuBar.add_menu menu

    action = collection.add_action 'quit', KDE::StandardAction::quit( self, SLOT( :close ), collection )
    menu.add_action action
    controlBar.add_action action

    menu = KDE::Menu.new i18n('&Play'), self
    menuBar.add_menu menu

    ini_phonon collection, menu, controlBar

    menu = KDE::Menu.new i18n('&Settings'), self
    menuBar.add_menu menu

    action = collection.add_action 'configure-keys', KDE::StandardAction::keyBindings( self, SLOT( :configureKeys ), collection )
    menu.add_action action

    menuBar.add_menu helpMenu

    collection.associate_widget self
    collection.read_settings
    set_auto_save_settings

    menuBar.show
    controlBar.show

    setCentralWidget @videoPlayer

    menu = KDE::Menu.new i18n('&View'), self
    menuBar.add_menu menu

    # add clip list dock widget
    dock = Qt::DockWidget.new self
    action = collection.add_action 'toogle-listwidgetcontainer-dock', dock.toggle_view_action
    menu.add_action action
    dock.objectName = "listWidgetContainerDock"
    dock.windowTitle = "Clips"
    dock.allowedAreas = Qt::LeftDockWidgetArea | Qt::RightDockWidgetArea
    self.add_dock_widget Qt::LeftDockWidgetArea, dock

    @listWidget = Qt::ListView.new dock
    dock.widget = @listWidget
#     @listWidget.view_mode = Qt::ListView::ListMode
    @listWidget.item_delegate = VideoItemDelegate.new(self)
    @listWidget.selection_mode = Qt::AbstractItemView::ExtendedSelection
    @listWidget.vertical_scroll_mode = Qt::AbstractItemView::ScrollPerPixel
    @listWidget.frame_shape = Qt::Frame::NoFrame
    # @listWidget.attribute = Qt::WA_MacShowFocusRect, false FIXME
    @listWidget.minimum_size = Qt::Size.new(320, 240)
    @listWidget.uniform_item_sizes = true

    @videoList =  VideoList.new
    @listWidget.model = @videoList
    connect(@listWidget, SIGNAL('activated(QModelIndex)')) do |modelIndex|
      if @videoList.include? modelIndex.row
        @videoList.active = modelIndex.row
      else
        # TODO search button
      end
    end

    connect(@videoList, SIGNAL('active_row_changed(int)')) do |row|
      video = @videoList[row]
      @active_video = video
      video.request_video_url
    end

    connect(@videoList, SIGNAL('play_this(QVariant)')) do |variant|
      video = variant.value
      if @active_video == video
	@videoPlayer.play Phonon::MediaSource.new video.video_url
      end
    end

    # add search field
    @searchWidget = KDE::LineEdit.new self
    @searchWidget.clear_button_shown = true
    @searchWidget.connect( SIGNAL :returnPressed ) do
      query @searchWidget.text, 0
      @searchWidget.clear
    end
    controlBar.add_widget @searchWidget

    # video_url = 'http://www.youtube.com/get_video?video_id=BU9w9ZtiO8I&t=vjVQa1PpcFPXqhCZqn_V_fcSdspsKvB16IM6uoGvNug=&eurl=&el=embedded&ps=default&fmt=18'
#     video_url = '/home/rriemann/Documents/Videos/Player/Austin_Powers_Goldstaender_08.08.15_20-15_rtl2_115_TVOON_DE.mpg.mp4-cut.avi'
    # @videoPlayer.play Phonon::MediaSource.new video_url

    @searchWidget.focus = Qt::OtherFocusReason
    self.show
  end

  def query query, start
    max_results = 25
    uri = URI.parse "http://gdata.youtube.com/feeds/api/videos?q=#{CGI.escape query}&max-results=#{max_results}&start-index=#{start+1}&alt=json"
    response, body = Net::HTTP.start(uri.host, uri.port) do |http|
      http.get(uri.path+'?'+uri.query)
    end
    JSON.parse( body )["feed"]["entry"].each do |entry|
      if (video = YoutubeVideo.get( KDE::Url.new(entry["link"][0]["href"]) ))
        video.title = entry["title"]["$t"]
        video.thumbnail_url = KDE::Url.new(entry["media$group"]["media$thumbnail"][-1]["url"])
        video.duration = entry["media$group"]["yt$duration"]["seconds"].to_f
        video.author = entry["author"][0]["name"]["$t"]
        @videoList.push video
      end
    end
  end

end

end

if $0 == __FILE__

  about = KDE::AboutData.new(
    "kminitube",                           # internal application name
    # language catlog name for i10n (konqueror's catalog for the beginning is better than no catalog)
    "konqueror",
    KDE.ki18n("KMiniTube"),                 # application name in the about menu and everywhere else
    "0.1",                             # application version
    KDE::ki18n("A Tool to easily create HTML formatted Code"),  # short description
    KDE::AboutData::License_GPL_V3,    # license
    KDE::ki18n("(c) 1999-2000, Name"), # copyright info
    # text in the about box - maybe with \n line breaks
    KDE::ki18n("just some text in the about box"),
    # project homepage and eMail adress for bug reports - attention: homepage changes standard dbus/dcop name!
    "http://homepage.de", "bugs@homepage.de" )
  about.setProgramIconName  "plasma" # use the plasma-icon instead of question mark

  KDE::CmdLineArgs.init(ARGV, about)

#   unless KDE::UniqueApplication.start
#     STDERR.puts "is already running."
#   else
#     a = KDE::UniqueApplication.new
#     w = Kube::MainWindow.new
#     a.exec
#   end
 a = KDE::Application.new
 w = Kube::MainWindow.new
 a.exec
end
