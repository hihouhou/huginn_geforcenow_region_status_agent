module Agents
  class GeforcenowRegionStatusAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_5m'

    description do
      <<-MD
      The huginn Geforcenow Region status agent checks the patching / maintenance game for region(s) Geforcenow status.

      `debug` is used to verbose mode.

      `region` is for the wanted region(s).

      `finsihed` is used for creating an event when patching/maintenance is finished for a game.

      `changes_only` is only used to emit event about a currency's change.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "id": 100936011,
            "title": "Path of Exile",
            "sortName": "path_of_exilepath_of_exile_egs",
            "isFullyOptimized": true,
            "steamUrl": "",
            "store": "Epic",
            "publisher": "Grinding Gear Games",
            "genres": [
              "Avanturističke",
              "Besplatno za igranje",
              "Velike internetske igre za više igrača",
              "Igre s ulogama"
            ],
            "status": "PATCHING"
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'finished' => 'false',
        'expected_receive_period_in_days' => '2',
        'region' => '["NP-STH-01", "NP-STH-02"]',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :region, type: :string, values: '[""]'
    form_configurable :finished, type: :boolean
    form_configurable :debug, type: :boolean

    def validate_options

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      if options.has_key?('finished') && boolify(options['finished']).nil?
        errors.add(:base, "if provided, finished must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      check_status
    end

    private

    def check_region(region,type)
      url = "https://prod-game-assets.s3.amazonaws.com/supported-public-game-list/gfnpc-" + type + "-" + region + ".json"
      uri = URI.parse(url)
      request = Net::HTTP::Get.new(uri)
      request["Connection"] = "keep-alive"
      request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.87 Safari/537.36"
      request["Accept"] = "*/*"
      request["Sec-Gpc"] = "1"
      request["Origin"] = "https://status.geforcenow.com"
      request["Sec-Fetch-Site"] = "cross-site"
      request["Sec-Fetch-Mode"] = "cors"
      request["Sec-Fetch-Dest"] = "empty"
      request["Referer"] = "https://status.geforcenow.com/"
      request["Accept-Language"] = "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      if interpolated['debug'] == 'true'
        log "response.body"
        log response.body
      end

      log "fetch status request status : #{response.code}"
      return response.body
      
    end

    def check_status()

      JSON.parse(interpolated['region']).each do |item|
        types = ["maintenance", "patching"]
        for type in types do
          payload = JSON.parse(check_region(item,type))
          last_status_type = "last_status_" + type + "_" + item
          if interpolated['changes_only'] == 'true'
            if payload.to_s != memory[last_status_type]
              if "#{memory[last_status_type]}" == ''
                payload.each do |k, v|
                  create_event payload: k
                end
              else
                last_status = memory[last_status_type].gsub("=>", ": ").gsub(": nil", ": null")
                last_status = JSON.parse(last_status)
                if interpolated['debug'] == 'true'
                  log "last_status"
                  log last_status
                end
                payload.each do |k, v|
                  found = false
                  last_status.each do |kbis, vbis|
                    if k == kbis
                      found = true
                      if interpolated['debug'] == 'true'
                        log "found is #{found}"
                      end
                    end
                  end
                  if found == false
                    create_event payload: k
                  else
                    if interpolated['debug'] == 'true'
                      log "found is #{found}"
                    end
                    
                  end
                end
                if interpolated['finished'] == 'true'
                  if interpolated['debug'] == 'true'
                    log "finished enabled"
                  end
                  last_status = memory[last_status_type].gsub("=>", ": ").gsub(": nil", ": null")
                  last_status = JSON.parse(last_status)
                  last_status.each do |kbis, vbis|
                    found = false
                    payload.each do |k, v|
                      if k == kbis
                        found = true
                        if interpolated['debug'] == 'true'
                          log "found is #{found}"
                        end
                      end
                    end
                    if found == false
                      kbis['status'] = kbis['status'] + " is FINISHED"
                      create_event payload: kbis
                    else
                      if interpolated['debug'] == 'true'
                        log "found is #{found}"
                      end
                      
                    end
                  end
                end
              end
              memory[last_status_type] = payload.to_s
            else
                if interpolated['debug'] == 'true'
                  log "no diff"
                end
            end
          else
            create_event payload: payload
            if payload.to_s != memory[last_status_type]
              memory[last_status_type] = payload.to_s
            end
          end
        end
      end
    end
  end
end
