require 'rubygems'
['mechanize', 'logger'].each do |gem|
  begin
    require gem
  rescue LoadError
    puts "You need to install #{gem}: gem install #{gem}"
    exit!(1)
  end
end

class OmahaPermitLookup
  attr_accessor :permit_number, :agent

  def initialize(permit_number)
    @permit_number = permit_number
    @agent = get_new_agent
    @logger = Logger.new($stderr)
    @logger.info("Initialized for: " + permit_number)
  end

  def fetch
    process
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
      unless(rows[index] && rows[index].search('td')[2])
        break
      end
      if(rows[index].search('td')[2].search('span').first)
        permit_row[:date] = rows[index].search('td')[2].search('span').first.text
      else
        # not a row!
        break
      end
      if(rows[index].search('td')[3].search('span').first)
        permit_row[:permit_number] = rows[index].search('td')[3].search('span').first.text
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
        permit_row[:site_address] = rows[index].search('td')[5].search('span').first.text
      else
        # the permit address is null
        permit_row[:site_address] = ""
      end
      if(rows[index].search('td')[6].search('span').first)
        permit_row[:current_status] = rows[index].search('td')[6].search('span').first.text
      else
        # the permit status is null
        permit_row[:current_status] = ""
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

  def parse_permit_details(p)
    details = Hash.new
    details[:contractor_id] = p.search('//table[@class="table_child"]')[2].text.split("CONTRACTOR").last.strip
    description = ""
    p.search('//table[@class="table_child"]')[3].search('td').last.children.each do |child|
      description += (child.to_s.strip + "\n")
    end
    details[:project_description] = description
    details[:parcel] = Hash.new
    details[:parcel][:number] = p.search('//div[@id="ctl00_PlaceHolderMain_PermitDetailList1_palParceList"]').first.search('div')[1].text
    details[:parcel][:lot] = p.search('//div[@id="ctl00_PlaceHolderMain_PermitDetailList1_palParceList"]').first.search('div')[3].text
    details[:parcel][:block] = p.search('//div[@id="ctl00_PlaceHolderMain_PermitDetailList1_palParceList"]').first.search('div')[5].text
    details[:parcel][:legal_description] = p.search('//div[@id="ctl00_PlaceHolderMain_PermitDetailList1_palParceList"]').first.search('div')[7].text
    details[:parcel][:land_value] = p.search('//div[@id="ctl00_PlaceHolderMain_PermitDetailList1_palParceList"]').first.search('div')[9].text
    details[:parcel][:improved_value] = p.search('//div[@id="ctl00_PlaceHolderMain_PermitDetailList1_palParceList"]').first.search('div')[11].text
    return details
  end

  def get_new_agent
    agent = Mechanize.new do |a| 
      a.read_timeout=30
      a.log = @logger
      #  a.log.level = 1 
      a.user_agent_alias = 'Mac Safari'
    end
    return agent
  end

  def process
    login_url = 'https://www.omahapermits.com/PermitInfo/Cap/CapHome.aspx?module=Permits&TabName=Permits'
    @logger.info "Loading search form"
    page = agent.get(login_url)
    f = page.form_with(:name => 'aspnetForm')
    f['ctl00$PlaceHolderMain$txtGSStartDate'] = "1/1/1901"
    f['ctl00$PlaceHolderMain$txtGSEndDate'] = Time.new.strftime("%m/%d/%Y") 
    if(@permit_type)
      f['ctl00$PlaceHolderMain$txtGSPermitNumber'] = @permit_number
    end

    @logger.info "Searching for permit data:"
    p = page.link_with(:text => "Search").asp_click


    @logger.info "  Parsing metadata"
    tmp_result = parse_permit_data(p)
    if(tmp_result.count > 0)
      permit = tmp_result.first
      l = nil
      p.links.each do |link|
        if(link.href && (link.href.include? "CapDetail.aspx"))
          l = link
        end
      end
      p = l.click
      details = parse_permit_details(p)
      return permit.merge(details)
#      return permit, details
    else
      return Hash.new
    end
  end
end
