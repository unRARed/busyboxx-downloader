#!/usr/bin/env ruby

require 'watir_angular'
require 'webdrivers'
require 'watir'
require 'byebug'

############################################################################
## Hacky script to (slowly) download busybox content headlessly.          ##
##                                                                        ##
## Relies on env variables BUSYBOXX_EMAIL and BUSYBOXX_PASSWORD           ##
##                                                                        ##
## Example call:                                                          ##
## ./download.rb - gets all content.                                      ##
## ./download.rb 3 - gets all third lib content.                          ##
## ./download.rb 5 4 - gets fifth lib content beginning less first three. ##
##                                                                        ##
#############################################################################

SOURCE =
  case ARGV[0]
  when 'animation'
    'Animation-Boxx'
  when 'busy'
    'busyBoxx'
  else
    raise 'Must specify source (busy or animation).'
  end

BASE_URL = "https://www.#{SOURCE}.com"

LIB_NUMBER = ARGV[1].to_i || nil
FIRST_ITEM = ARGV[2].to_i || nil

Watir.default_timeout = 60
prefs = {
  download: {
    prompt_for_download: false,
    # default_directory: "/Fileserver/nas/video effects"
    default_directory: "/Volumes/Public/video effects"
  },
  webkit: { webprefs: { loads_images_automatically: false } }
}
browser = Watir::Browser.new :chrome, options: { prefs: prefs }

#profile = Selenium::WebDriver::Firefox::Profile.new
#profile['browser.download.folderList'] = 2 # custom location
#profile['browser.download.dir'] = "/Fileserver/nas/video effects"
#browser = Watir::Browser.new :firefox, option: { profile: profile}#, headless: true

# Wait for login form
puts 'Logging in'
browser.goto(
  "https://account.busyboxx.com/LogIn/#{SOURCE == 'busy' ? '' : SOURCE}"
)
sleep 5

# Fill in the form
puts 'Filling login form'
browser.text_field(name: 'EmailAddress').set ENV['BUSYBOXX_EMAIL']
browser.text_field(name: 'Password').set ENV['BUSYBOXX_PASSWORD']
puts 'Submitting form'
browser.button(name: 'SignInButton').click

puts 'Waiting for homepage / download link'
browser.window(title: "#{SOURCE} : Home").wait_until(&:exists?)

# Download stuff
puts 'Moving to /Downloads'
browser.goto("#{BASE_URL}/Downloads")
# Wait for libs to load
puts 'Waiting for libs to load'
browser.window(title: "#{SOURCE} : Downloads").wait_until(&:exists?)
browser.div(class: 'contentsToDisplay').wait_until(&:exists?)

library_links = browser.links(href: /Downloads\?path/)
library_links = [library_links[LIB_NUMBER - 1]] if LIB_NUMBER
library_links.each do |lib_link|
  puts 'Moving to /Downloads/[LIBRARY]'
  browser.goto lib_link.href
  # Wait for cards to load
  browser.elements(tag_name: 'p', class: 'Duration').wait_until(&:exists?)
  #sleep 30
  items = browser.elements(tag_name: 'i', class: 'DownloadCloud')
  # 10 minutes between iterations
  sleep_time_total = (60 * 10)
  sleep_time = sleep_time_total
  items.each_with_index do |item, index|
    # ensure we respect the 5 per 5 minute lamesauce
    next if FIRST_ITEM && index < (FIRST_ITEM - 1)
    if index > 0 && index % 3 == 0 && index != (FIRST_ITEM - 1)
      sleep sleep_time if sleep_time > 0
      sleep_time = sleep_time_total
    end
    title = item.parent.parent.
      elements(class: 'ContentExtraInfoSuperTitle').first.text
    file_size_value = item.parent.parent.
      elements(class: 'ContentExtraInfoSubTitle').last.text
    file_size = file_size_value.include?('GB') ?
      (file_size_value.to_f * 1000).to_i : file_size_value.to_i
    puts "Downloading #{title}"
    item.click
    sleep_time = (sleep_time - file_size)
    sleep file_size
  end
end
