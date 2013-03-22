=begin
  Scrape www.sec.gov website for daily filings.
=end
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'mechanize'

$db = SQLite3::Database.new('edgar.sqlite')
$db.execute "CREATE TABLE IF NOT EXISTS SECFilings(
  cik     INTEGER NOT NULL,
  form    VARCHAR(12) NOT NULL,
  doclink VARCHAR(256) NOT NULL,
  comlink VARCHAR(256) NOT NULL,
  date    DATE NOT NULL)"

$agent = Mechanize.new
$base_url = "http://www.sec.gov"
$filing_a = []

# fetch the starting page...
$agent.get("#{$base_url}/edgar/searchedgar/currentevents.htm") do |search_page|
  results_page = search_page.form_with(:action=>"/cgi-bin/current.pl") do |form|
    form['q1']="0"
    form['q2']="6"
    form['q3']="N-Q"
  end.submit

  # process the results page which contains a table of latest filings...
  anchor_a = results_page.parser.css('pre a').to_a
  hash = Hash.new
  anchor_a.each_index do |i|
    if i.even?
      # new filing...
      hash = Hash.new
      hash[:FormType] = anchor_a[i].text.strip # N-Q
      hash[:FormURL] = anchor_a[i]['href']
    else
      hash[:CIK] = anchor_a[i].text.strip
      hash[:CompanyURL] = anchor_a[i]['href']
      $filing_a << hash
    end
  end

  # fetch the document link for each filing...
  $filing_a.each do |hash|
    url = $base_url+hash[:FormURL]
    page = Nokogiri::HTML(open(url))
    hash[:FilingDate] = page.css('div.formContent div.formGrouping div.info')[0].text.strip
    hash[:DocumentURL] = page.css('table.tableFile tr td a')[0]['href']
  end
  
  # update db
  $filing_a.each do |hash|
    $db.execute "INSERT INTO SECFilings 
      VALUES 
      (?,?,?,?,?)",
      [
        hash[:CIK],
        hash[:FormType],
        $base_url+hash[:DocumentURL],
        $base_url+hash[:CompanyURL],
        hash[:FilingDate]
      ]
  end  
end
