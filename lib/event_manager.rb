require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = convert_number_format(phone_number)

  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == "1"
    phone_number[1..10]
  else
    'Invalid phone number entered'
  end
end

def convert_number_format(number)
  result = ''
  number.each_char do |char|
    result += char if char.match?(/[[:digit:]]/)
  end
  result
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def peak_times(frequency_hash)
  max_frequency = frequency_hash.values.max
  result = frequency_hash.reduce([]) do |peak_times, (time, frequency)|
    peak_times.push(time) if frequency == max_frequency
    peak_times
  end

  result
end

DAY_HASH = {
  '0': "Sunday",
  '1': "Monday",
  '2': "Tuesday",
  '3': "Wednesday",
  '4': "Thursday",
  '5': "Friday",
  '6': "Saturday"
}

def convert_to_days(day_nums)
  result = day_nums.map do |day_num|
    DAY_HASH[day_num.to_s.to_sym]
  end

  result.join(", ")
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

hour_frequencies = Hash.new(0)
day_frequencies = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  home_phone = clean_phone_number(row[:homephone])

  reg_date = Time.strptime(row[:regdate], "%D %R")

  hour_frequencies[reg_date.hour] += 1
  day_frequencies[reg_date.to_date.wday] += 1

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

peak_hours = peak_times(hour_frequencies)
puts "Peak hours are #{peak_hours}"

peak_days = convert_to_days(peak_times(day_frequencies))
puts "Peak days are #{peak_days}"
