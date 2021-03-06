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
## Command line options                                                   ##
##   --source (STR) ('busy' or 'animation') - where to download from.     ##
##   --library (INT) - target the `n`th of your owned libraries.          ##
##   --start (INT) - skip downloading the libraries listed prior.         ##
##   --speed (STR) - ('slow' or 'fast') time to wait between iterations.  ##
##                                                                        ##
## Example calls:                                                         ##
## ./download.rb --source busy                                            ##
## ./download.rb --source busy --library 5                                ##
## ./download.rb --source animation --library 1 --start 3                 ##
## ./download.rb --source animation --library 1 --start 3  --speed fast   ##
#############################################################################

args = ARGV
values = args.select{|item| !item.start_with? '--'}
keys = (args - values).map{|item| item[2..-1] }

options = {}
keys.length.times do |i|
  options[keys[i]] = values[i]
end

unless (values.count + keys.count) == args.count
  raise 'Invalid argument(s). '\
    'Valid arguments are --source, --library and --start'
end

SOURCE =
  case options['source']
  when 'animation'
    'Animation-Boxx'
  when 'busy'
    'busyBoxx'
  else
    raise 'Must specify source (busy or animation).'
  end

MINUTES =
  case options['speed']
  when 'fast'
    5
  when 'slow'
    20
  else
    10
  end

BASE_URL = "https://www.#{SOURCE}.com"
LIB_NUMBER = options['library'].to_i || nil
START = options['start'].to_i || nil

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

# TODO: Add Firefox support (maybe)
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
  items = browser.elements(tag_name: 'i', class: 'DownloadCloud')

  # Time between iterations
  seconds_to_sleep = (60 * MINUTES)
  sleep_delta = seconds_to_sleep

  items.each_with_index do |item, index|
    # Ensure we respect the 5 per 5 minute lamesauce
    next if START && index < (START - 1)
    if index > 0 && index % 3 == 0 && index != (START - 1)
      # Reached the end of the loop, so we
      # sleep any time remaining then continue...
      sleep sleep_delta if sleep_delta > 0
      sleep_delta = seconds_to_sleep
    end

    # Download the thing
    title = item.parent.parent.
      elements(class: 'ContentExtraInfoSuperTitle').first.text
    puts "Downloading #{title}"
    item.click

    # Dynamically determine sleep time between
    # downloads at static rate of 1MB/sec
    file_size_value = item.parent.parent.
      elements(class: 'ContentExtraInfoSubTitle').last.text
    file_size = file_size_value.include?('GB') ?
      (file_size_value.to_f * 1000).to_i : file_size_value.to_i
    file_size =
      case options['speed']
      when 'fast'
        (file_size / 2).to_i
      when 'slow'
        (file_size * 2).to_i
      else
        file_size
      end
    sleep_delta = (sleep_delta - file_size)
    sleep file_size
  end
end
