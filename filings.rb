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
  filing_date DATE NOT NULL,
  form_type   VARCHAR NOT NULL, 
  doc_link    VARCHAR NOT NULL UNIQUE, 
  cik         VARCHAR NOT NULL, 
  series      VARCHAR,
  FOREIGN KEY (cik) REFERENCES SECFiler(cik)
  )"

$db.execute "CREATE TABLE IF NOT EXISTS SECFiler(
  cik           VARCHAR PRIMARY KEY  NOT NULL,
  filer_name    VARCHAR,
  mailing_addr  VARCHAR,
  business_addr VARCHAR
  )"

$db.execute "CREATE TABLE IF NOT EXISTS FundSeries(
  series_id   VARCHAR PRIMARY KEY NOT NULL,
  series_name VARCHAR,
  cik         VARCHAR NOT NULL,
  FOREIGN KEY (cik) REFERENCES SECFiler(cik)
  )"

$db.execute "CREATE TABLE IF NOT EXISTS FundClass(
  class_id    VARCHAR PRIMARY KEY NOT NULL,
  class_name  VARCHAR,
  ticker      VARCHAR,
  series_id   VARCHAR NOT NULL,
  FOREIGN KEY (series_id) REFERENCES FundSeries(series_id)
  )"

$agent = Mechanize.new
$base_url = "http://www.sec.gov"
$form_type_a = ["N-Q", "497K", "485APOS"]

#
# scrape filer information from the filing index page
#
def scrape_filer(page)
  # obtain the filer name...
  index = page.css('span.companyName').text.index('(Filer)')
  if index
    filer_name = page.css('span.companyName').text[0..index-1].strip
    
    # cik...
    index = page.css('span.companyName a').text.index('(see all company filings)')
    if index
      cik = page.css('span.companyName a').text[0..index-1].strip

      # update SECFiler table
      $db.execute "INSERT OR REPLACE INTO SECFiler 
        VALUES 
        (?,?,?,?)",
        [
          cik,
          filer_name,
          page.css('div.mailer')[0].css('span.mailerAddress').text.strip,
          page.css('div.mailer')[1].css('span.mailerAddress').text.strip
        ]

      # obtain the series and classes covered by this filing...
      rows = page.css('table.tableSeries tr')[3..-1]
      if rows
        series_id = nil
        rows.each do |row|
          # check if series row...
          cell = row.css('td.seriesName')
          if not cell.empty?
            # collect the series id and name...
            series_id = row.css('td.seriesName a').text.strip
            series_name = row.css('td.seriesCell').text.strip

            # update FundSeries table
            $db.execute "INSERT OR REPLACE INTO FundSeries 
              VALUES 
              (?,?,?)",
              [
                series_id,
                series_name,
                cik
              ]
          else
            cell = row.css('td.classContract')
            if not cell.empty?
              # collect the class id, name and ticker...
              class_id = row.css('td.classContract a').text.strip
              class_name = row.css('td')[2].text.strip
              ticker = row.css('td')[3].text.strip

              # update FundClass table
              $db.execute "INSERT OR REPLACE INTO FundClass 
                VALUES 
                (?,?,?,?)",
                [
                  class_id,
                  class_name,
                  ticker,
                  series_id
                ]
            end
          end
        end
      end
    end
  end
end

# fetch the starting page...
$agent.get("#{$base_url}/edgar/searchedgar/currentevents.htm") do |search_page|
  results_page = search_page.form_with(:action=>"/cgi-bin/current.pl") do |form|
    form['q1']="0"
    form['q2']="6"
    form['q3']="N-Q"
  end.submit

  # process the results page which contains a table of latest filings...
  puts results_page.parser.css('p').text.strip
  anchor_a = results_page.parser.css('pre a').to_a
  form_type = nil
  form_link = nil
  anchor_a.each_index do |i|
    if i.even?
      # new filing...
      form_type = anchor_a[i].text.strip # N-Q
      form_link = anchor_a[i]['href']
    else
      # fetch filings only for the desired form types...
      if form_type and $form_type_a.include?(form_type)
        cik = anchor_a[i].text.strip
        #com_link = anchor_a[i]['href']

        url = $base_url+form_link
        page = Nokogiri::HTML(open(url))
        scrape_filer(page)

        # fetch the document link for each filing...
        filing_date = page.css('div.formContent div.formGrouping div.info')[0].text.strip
        doc_link = page.css('table.tableFile tr td a')[0]['href']

        # obtain the series and classes covered by this filing...
        rows = page.css('table.tableSeries tr')[3..-1]
        series = []
        if rows
          rows.each do |row|
            # check if series row...
            cell = row.css('td.seriesName')
            if not cell.empty?
              # collect the series ids...
              series_id = row.css('td.seriesName a').text.strip
              if not series_id.empty?
                series << series_id
              end
            end
          end
        end

        puts "#{filing_date},#{form_type},#{doc_link},#{cik},#{series.join(",")}"
        # update SECFilings table
        $db.execute "INSERT OR IGNORE INTO SECFilings 
          VALUES 
          (?,?,?,?,?)",
          [
            filing_date,
            form_type,
            $base_url+doc_link,
            cik,
            series.join(",")
          ]
      end
    end
  end
end
