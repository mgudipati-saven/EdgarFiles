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
  cik_code    VARCHAR NOT NULL, 
  form_type   VARCHAR NOT NULL, 
  doc_link    VARCHAR NOT NULL UNIQUE, 
  com_link    VARCHAR NOT NULL, 
  filing_date DATE NOT NULL)"

$agent = Mechanize.new
$base_url = "http://www.sec.gov"
$form_type_a = ["N-Q", "497K", "485APOS"]

# fetch the starting page...
$agent.get("#{$base_url}/edgar/searchedgar/currentevents.htm") do |search_page|
  results_page = search_page.form_with(:action=>"/cgi-bin/current.pl") do |form|
    form['q1']="0"
    form['q2']="6"
    #form['q3']="N-Q"
  end.submit

  # process the results page which contains a table of latest filings...
  puts results_page.parser.css('p').text.strip
  anchor_a = results_page.parser.css('pre a').to_a
  form_type = nil
  form_link = nil
  cik_code = nil
  filing_date = nil
  anchor_a.each_index do |i|
    if i.even?
      # new filing...
      form_type = anchor_a[i].text.strip # N-Q
      form_link = anchor_a[i]['href']
    else
      # fetch filings only for the desired form types...
      if form_type and $form_type_a.include?(form_type)
        cik_code = anchor_a[i].text.strip
        com_link = anchor_a[i]['href']

        # fetch the document link for each filing...
        url = $base_url+form_link
        page = Nokogiri::HTML(open(url))
        filing_date = page.css('div.formContent div.formGrouping div.info')[0].text.strip
        doc_link = page.css('table.tableFile tr td a')[0]['href']
        puts "#{cik_code},#{form_type},#{doc_link},#{com_link},#{filing_date}"
        # update db
        if cik_code and form_type and doc_link and com_link and filing_date
          $db.execute "INSERT OR IGNORE INTO SECFilings 
            VALUES 
            (?,?,?,?,?)",
            [
              cik_code,
              form_type,
              $base_url+doc_link,
              $base_url+com_link,
              filing_date
            ]
        end
      end
    end
  end
end
