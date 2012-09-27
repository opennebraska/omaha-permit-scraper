require 'rubygems'
['mechanize', 'logger'].each do |gem|
  begin
    require gem
  rescue LoadError
    puts "You need to install #{gem}: gem install #{gem}"
    exit!(1)
  end
end

class OmahaPermitParser
  attr_accessor :start_date, :end_date, :permit_type, :agent, :logger

  def initialize(start_date, end_date, permit_type=nil)
    @start_date = start_date
    @end_date = end_date
    @permit_type = permit_type
    @agent = get_new_agent
    @logger = Logger.new($stderr)
  end

  def scrape
    search
  end

  private

  class Mechanize::Page::Link
    def asp_click(action_arg = nil)
      etarget,earg = asp_link_args.values_at(0, 1)
      f = self.page.form_with(:name => 'aspnetForm')
      f.action = asp_link_args.values_at(action_arg) if action_arg
      f['__EVENTTARGET'] = etarget
      f['__EVENTARGUMENT'] = earg
      f.submit
    end
    def asp_link_args
      href = self.attributes['href']
      href =~ /\(([^()]+)\)/ && $1.split(/\W?\s*,\s*\W?/).map(&:strip).map {|i| i.gsub(/^['"]|['"]$/,'')}
    end
  end

  def parse_permit_data(page_object)
    permits_recovered = Array.new
    rows = page_object.search('//*[@id="ctl00_PlaceHolderMain_dgvPermitList_gdvPermitList"]/tr')
    (2..11).each do |index|
      permit_row = Hash.new
      if(rows[index].search('td')[2].search('span').first)
        permit_row[:date] = rows[index].search('td')[2].search('span').first.text
      else
        # not a row!
        break
      end
      if(rows[index].search('td')[3].search('span').first)
        permit_row[:number] = rows[index].search('td')[3].search('span').first.text
      else
        # the permit number is null
        break
      end
      if(rows[index].search('td')[4].search('span').first)
        permit_row[:type] = rows[index].search('td')[4].search('span').first.text
      else
        # the permit type is null
        next
      end
      if(rows[index].search('td')[5].search('span').first)
        permit_row[:address] = rows[index].search('td')[5].search('span').first.text
      else
        # the permit address is null
        permit_row[:address] = ""
      end
      if(rows[index].search('td')[6].search('span').first)
        permit_row[:status] = rows[index].search('td')[6].search('span').first.text
      else
        # the permit status is null
        permit_row[:status] = ""
      end
      if(rows[index].search('td')[7].search('span').first)
        permit_row[:pending_actions] = rows[index].search('td')[7].search('span').first.text
      else
        # the permit number is null
        permit_row[:pending_actions] = ""
      end
      permits_recovered.push(permit_row)
    end
    return permits_recovered
  end

  def get_new_agent
    agent = Mechanize.new do |a| 
      a.log = @logger
      #  a.log.level = 1 
      a.user_agent_alias = 'Mac Safari'
    end
    return agent
  end

  def run
    login_url = 'https://www.omahapermits.com/PermitInfo/Cap/CapHome.aspx?module=Permits&TabName=Permits'
    @logger.info "Loading search form"
    page = agent.get(login_url)
    f = page.form_with(:name => 'aspnetForm')
    f['ctl00$PlaceHolderMain$txtGSStartDate'] = @start_date
    f['ctl00$PlaceHolderMain$txtGSEndDate'] = @end_date
    if(@permit_type)
      f['ctl00$PlaceHolderMain$txtGSPermitNumber'] = @permit_type
    end

    @logger.info "Loading first page of search results:"
    p = page.link_with(:text => "Search").asp_click

    permits = []

    loop do
      @logger.info "  Parsing page"
      tmp_result = parse_permit_data(p)
      if(tmp_result.count > 0)
        @logger.info "  Found " + tmp_result.count.to_s + " permits on this page"
        permits.push(*tmp_result)
      else
        break
      end
      if(p.link_with(:text => "Next >"))
        @logger.info "Loading next page:"
        p = p.link_with(:text => "Next >").asp_click
      else
        @logger.info "Done: " + permits.count.to_s
        break
      end
    end
    return permits
  end
end
