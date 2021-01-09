module Agents
  class YnabAgent < Agent
    include FormConfigurable

    can_dry_run!
    cannot_be_scheduled!

    def working?
      true
    end

    def default_options
      {}
    end

    form_configurable :ynab_token
    def validate_options
      if options['ynab_token'].blank?
        errors.add(:base, 'YNAB access token is required')
      end
    end

    def default_options
      {'ynab_token' => "{% credential YNAB_TOKEN %}"}
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        log("Creating transaction with payee #{event.payload['payee_name']}")
        payload = {
          'transaction' => {
            'account_id' => event.payload['account_id'],
            'category_id' => event.payload['category_id'],
            'payee_name' => event.payload['payee_name'],
            'date' => event.payload['date'] || Date.today.to_s,
            'amount' => (event.payload['amount'] * 1000).to_i,
            'memo' => event.payload['memo'] || '',
            'cleared' => event.payload['cleared'] || 'uncleared',
          },
        }

        url = "https://api.youneedabudget.com/v1/budgets/#{event.payload['budget_id']}/transactions"
        resp = Faraday.post(url, payload.to_json) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.headers['Authorization'] = "Bearer #{interpolated['ynab_token']}"
        end

        if resp.status < 200 || resp.status >= 300
          error("Received bad response from YNAB (#{resp.status}): #{resp.body}")
        else
          log("Success!\n Response: #{resp.body}")
          create_event payload: JSON.parse(resp.body)['data']
        end
      end
    end
  end
end
