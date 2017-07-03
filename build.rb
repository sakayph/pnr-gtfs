#!/usr/bin/env ruby

require 'csv'
require 'rexml/document'
require 'net/http'

prefix = 'MSC'
stations = 1..25
$route_id = 'MSC'
$service_id = 'EVERYDAY'

# STOPS

stop_list = CSV.read("stops.csv")
stops = CSV.open("gtfs/stops.txt", "wb")

stops << ["stop_id", "stop_name", "stop_lat", "stop_lon", "zone_id"]

stations.each do |i|
  stop_id = stop_list[i][1]
  stop_name = stop_list[i][0]
  stop_lat = stop_list[i][2]
  stop_lng = stop_list[i][3]
  stops << [stop_id, stop_name+" PNR", stop_lat, stop_lng, stop_id]
end

# TIMETABLE

timetable_nb = CSV.read("timetable_nb.csv")
timetable_sb = CSV.read("timetable_sb.csv")
$trips = CSV.open("gtfs/trips.txt", "wb")
$stop_times = CSV.open("gtfs/stop_times.txt", "wb")

$trips << ["trip_id", "route_id", "service_id", "shape_id"]
$stop_times << ["trip_id", "stop_sequence", "stop_id", "arrival_time", "departure_time"]

def parse_timetable(timetable, dir)
  timetable[0].each_index do |i|
    if timetable[0][i] != nil
      parse_trip(timetable, i, dir)
    end
  end
end

def parse_trip(timetable, i, dir)
  trip_id = timetable[0][i]
  $trips << [trip_id, $route_id, $service_id, dir]
  timetable
    .drop(2)
    .reject { |r| r[i] == nil }
    .each.with_index do |r, index|
      stop_id = r[1]
      arrival_time = r[i]
      departure_time = r[i+1]
      $stop_times << [trip_id, index+1, stop_id, arrival_time, departure_time]
    end
end

parse_timetable(timetable_nb, 'NB')
parse_timetable(timetable_sb, 'SB')

# FARES

fare_table = CSV.read("fares.csv")
fare_rules = CSV.open("gtfs/fare_rules.txt", "wb")
fare_attributes = CSV.open("gtfs/fare_attributes.txt", "wb")

fare_rules << ["fare_id", "origin_id", "destination_id"]
fare_attributes << ["fare_id", "price", "currency_type", "payment_method", "transfers"]

stations.each do |i|
  from_code = fare_table[i+1][1]
  stations.each do |j|
    to_code = fare_table[1][j+1]
    if i != j
      fare = fare_table[i+1][j+1]
      fare_id = sprintf("%s-%s-%s", prefix, from_code, to_code)

      fare_rules << [fare_id, from_code, to_code]
      fare_attributes << [fare_id, fare, "PHP", 1, 0]
    end
  end
end

fare_rules.close()
fare_attributes.close()

exit
# SHAPES

$shapes = CSV.open("gtfs/shapes.txt", "wb")

$shapes << ['shape_id', 'shape_pt_lat', 'shape_pt_lon', 'shape_pt_sequence']

def parse_shape_xml(doc)
  xml = REXML::Document.new doc
  nodes = Hash.new
  ways = Hash.new
  coords = nil
  xml.root.elements.each do |element|
    if element.name == 'node'
      nodes[element.attributes['id']] = [
        element.attributes['lon'],
        element.attributes['lat']
      ]
    elsif element.name == 'way'
      ways[element.attributes['id']] = element.elements
        .select { |x| x.name == 'nd' }
        .map { |x| x.attributes['ref'] }
    else
      coords = element.elements
        .select { |x| x.name == 'member' && x.attributes['type'] == 'way' }
        .map { |x| ways[x.attributes['ref']] }
        .flatten
        .map { |x| nodes[x] }
    end
  end
  coords
end

def fetch_shape(name)
  uri = URI('http://overpass-api.de/api/interpreter')
  query = <<EOF
  rel["name"="#{name}"];
  (._; way(r));
  (._; node(w));
  out;
EOF
  res = Net::HTTP.post(uri, query)
  if res.is_a?(Net::HTTPSuccess)
    coords = parse_shape_xml(res.body)
    coords.each.with_index do |coord, index|
      $shapes << ['SB', coord[1], coord[0], index]
    end
    coords.reverse.each.with_index do |coord, index|
      $shapes << ['NB', coord[1], coord[0], index]
    end
  else
    puts "Failed to get shape data"
  end
end

fetch_shape('PNR Metro Commuter Line : Tutuban - Calamba')
