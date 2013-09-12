module Helix

  module SignatureHandler

    unless defined?(self::VALID_SIG_TYPES)
      SIG_DURATION     = 1200 # in minutes
      TIME_OFFSET      = 1000 * 60 # 1000 minutes, lower to give some margin of error
      VALID_SIG_TYPES  = [ :ingest, :update, :view ]
    end

    def clear_signatures!
      @signature_for            = {}
      @signature_expiration_for = {}
    end

    # Fetches the signature for a specific license key.
    #
    # @param [Symbol] sig_type The type of signature required for calls.
    # @param [Hash] opts allows you to overide contributor and license_id
    # @return [String] The signature needed to pass around for calls.
    def signature(sig_type, opts={})
      prepare_signature_memoization
      memo_sig = existing_sig_for(sig_type)
      return memo_sig if memo_sig
      unless VALID_SIG_TYPES.include?(sig_type)
        raise ArgumentError, error_message_for(sig_type)
      end

      lk = license_key
      @signature_expiration_for[lk][sig_type] = Time.now + TIME_OFFSET
      new_sig_url                  = signature_url_for(sig_type, opts)
      @signature_for[lk][sig_type] = RestClient.get(new_sig_url)
    end

    private

    def existing_sig_for(sig_type)
      return if sig_expired_for?(sig_type)
      @signature_for[license_key][sig_type]
    end

    def license_key
      @credentials[:license_key]
    end

    def prepare_signature_memoization
      lk = license_key
      @signature_for                ||= {}
      @signature_expiration_for     ||= {}
      @signature_for[lk]            ||= {}
      @signature_expiration_for[lk] ||= {}
    end

    def sig_expired_for?(sig_type)
      expires_at = @signature_expiration_for[license_key][sig_type]
      return true if expires_at.nil?
      expires_at <= Time.now
    end

    def signature_url_for(sig_type, opts={})
      contributor, library, company = get_contributor_library_company(opts)
      url  = "#{credentials[:site]}/api/#{sig_type}_key?"
      url += "licenseKey=#{credentials[:license_key]}&duration=#{SIG_DURATION}"
      url += "&contributor=#{contributor}" if sig_type == :ingest
      url += "&library_id=#{library}"   if library
      url += "&company_id=#{company}"   if company
      url
    end

  end

end
