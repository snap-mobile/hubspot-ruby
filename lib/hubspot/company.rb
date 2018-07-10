class Hubspot::Company < Hubspot::Resource
  self.id_field = "companyId"
  self.property_name_field = "name"

  ADD_CONTACT_PATH        = '/companies/v2/companies/:id/contacts/:contact_id'
  ALL_PATH                = '/companies/v2/companies/paged'
  BATCH_UPDATE_PATH       = '/companies/v1/batch-async/update'
  CONTACTS_PATH           = '/companies/v2/companies/:id/contacts'
  CONTACT_IDS_PATH        = '/companies/v2/companies/:id/vids'
  CREATE_PATH             = '/companies/v2/companies/'
  DELETE_PATH             = '/companies/v2/companies/:id'
  FIND_PATH               = '/companies/v2/companies/:id'
  RECENTLY_CREATED_PATH   = '/companies/v2/companies/recent/created'
  RECENTLY_MODIFIED_PATH  = '/companies/v2/companies/recent/modified'
  REMOVE_CONTACT_PATH     = '/companies/v2/companies/:id/contacts/:contact_id'
  SEARCH_DOMAIN_PATH      = '/companies/v2/domains/:domain/companies'
  UPDATE_PATH             = '/companies/v2/companies/:id'

  class << self
    def all(opts = {})
      Hubspot::PagedCollection.new(opts) do |options, offset, limit|
        response = Hubspot::Connection.get_json(
          ALL_PATH,
          options.merge(offset: offset, limit: limit)
        )

        companies = response["companies"].map { |result| from_result(result) }

        [companies, response["offset"], response["has-more"]]
      end
    end

    def search_domain(domain, opts = {})
      Hubspot::PagedCollection.new(opts) do |options, offset, limit|
        request = {
          "limit" => limit,
          "requestOptions" => options,
          "offset" => {
            "isPrimary" => true,
            "companyId" => offset
          }
        }

        response = Hubspot::Connection.post_json(
          SEARCH_DOMAIN_PATH,
          params: { domain: domain },
          body: request
        )

        companies = response["results"].map { |result| from_result(result) }

        [companies, response["offset"]["companyId"], response["hasMore"]]
      end
    end

    def recently_created(opts = {})
      Hubspot::PagedCollection.new(opts) do |options, offset, limit|
        response = Hubspot::Connection.get_json(
          RECENTLY_CREATED_PATH,
          {offset: offset, count: limit}
        )

        companies = response["results"].map { |result| from_result(result) }

        [companies, response["offset"], response["hasMore"]]
      end
    end

    def recently_modified(opts = {})
      Hubspot::PagedCollection.new(opts) do |options, offset, limit|
        response = Hubspot::Connection.get_json(
          RECENTLY_MODIFIED_PATH,
          {offset: offset, count: limit}
        )

        companies = response["results"].map { |result| from_result(result) }

        [companies, response["offset"], response["hasMore"]]
      end
    end

    def add_contact(id, contact_id)
      Hubspot::Connection.put_json(
        ADD_CONTACT_PATH,
        params: { id: id, contact_id: contact_id }
      )
      true
    end

    def remove_contact(id, contact_id)
      Hubspot::Connection.delete_json(
        REMOVE_CONTACT_PATH,
        { id: id, contact_id: contact_id }
      )

      true
    end

    # Updates the properties of companies
    # NOTE: Up to 100 companies can be updated in a single request. There is no limit to the number of properties that can be updated per company.
    # {https://developers.hubspot.com/docs/methods/companies/batch-update-companies}
    # Returns a 202 Accepted response on success.
    def batch_update!(companies)
      query = companies.map do |company|
        company_hash = company.with_indifferent_access
        if company_hash[:vid]
          # For consistency - Since vid has been used everywhere.
          company_param = {
            objectId: company_hash[:vid],
            properties: Hubspot::Utils.hash_to_properties(company_hash.except(:vid).stringify_keys!, key_name: 'name'),
          }
        elsif company_hash[:objectId]
          company_param = {
            objectId: company_hash[:objectId],
            properties: Hubspot::Utils.hash_to_properties(company_hash.except(:objectId).stringify_keys!, key_name: 'name'),
          }
        else
          raise Hubspot::InvalidParams, 'expecting vid or objectId for company'
        end
        company_param
      end
      Hubspot::Connection.post_json(BATCH_UPDATE_PATH, params: {}, body: query)
    end

    # Adds contact to a company
    # {http://developers.hubspot.com/docs/methods/companies/add_contact_to_company}
    # @param company_vid [Integer] The ID of a company to add a contact to
    # @param contact_vid [Integer] contact id to add
    # @return parsed response
    def add_contact!(company_vid, contact_vid)
      Hubspot::Connection.put_json(ADD_CONTACT_TO_COMPANY_PATH,
                                    params: {
                                      company_id: company_vid,
                                      vid: contact_vid,
                                    },
                                    body: nil)
    end

    # Updates the properties of a company
    # {http://developers.hubspot.com/docs/methods/companies/update_company}
    # @param vid [Integer] hubspot company vid
    # @param params [Hash] hash of properties to update
    # @return [Hubspot::Company] Company record
    def update!(vid, params)
      params.stringify_keys!
      query = {"properties" => Hubspot::Utils.hash_to_properties(params, key_name: "name")}
      response = Hubspot::Connection.put_json(UPDATE_COMPANY_PATH, params: { company_id: vid }, body: query)
      new(response)
    end

    attr_reader :properties
    attr_reader :vid, :name

    def initialize(response_hash)
      @properties = Hubspot::Utils.properties_to_hash(response_hash["properties"])
      @vid = response_hash["companyId"]
      @name = @properties.try(:[], "name")
    end

    def [](property)
      @properties[property]
    end

    # Updates the properties of a company
    # {http://developers.hubspot.com/docs/methods/companies/update_company}
    # @param params [Hash] hash of properties to update
    # @return [Hubspot::Company] self
    def update!(params)
      self.class.update!(vid, params)
      @properties.merge!(params)
      self
    end

    # Gets ALL contact vids of a company
    # May make many calls if the company has a mega-ton of contacts
    # {http://developers.hubspot.com/docs/methods/companies/get_company_contacts_by_id}
    # @return [Array] contact vids
    def get_contact_vids
      vid_offset = nil
      vids = []
      loop do
        data = Hubspot::Connection.get_json(GET_COMPANY_CONTACT_VIDS_PATH,
                                            company_id: vid,
                                            vidOffset: vid_offset)
        vids += data['vids']
        return vids unless data['hasMore']
        vid_offset = data['vidOffset']
      end
      vids # this statement will never be executed.
    end

    # Adds contact to a company
    # {http://developers.hubspot.com/docs/methods/companies/add_contact_to_company}
    # @param id [Integer] contact id to add
    # @return [Hubspot::Company] self
    def add_contact(contact_or_vid)
      contact_vid = if contact_or_vid.is_a?(Hubspot::Contact)
                      contact_or_vid.vid
                    else
                      contact_or_vid
                    end
      self.class.add_contact!(vid, contact_vid)
      self
    end

    # Archives the company in hubspot
    # {http://developers.hubspot.com/docs/methods/companies/delete_company}
    # @return [TrueClass] true
    def destroy!
      Hubspot::Connection.delete_json(DESTROY_COMPANY_PATH, { company_id: vid })
      @destroyed = true
    end

    def destroyed?
      !!@destroyed
    end

    # Finds company contacts
    # {http://developers.hubspot.com/docs/methods/companies/get_company_contacts}
    # @return [Array] Array of Hubspot::Contact records
    def contacts
      response = Hubspot::Connection.get_json(GET_COMPANY_CONTACTS_PATH, company_id: vid)
      response['contacts'].each_with_object([]) do |contact, memo|
        memo << Hubspot::Contact.find_by_id(contact['vid'])
      end
    end

    def contact_ids(opts = {})
      Hubspot::PagedCollection.new(opts) do |options, offset, limit|
        response = Hubspot::Connection.get_json(
          CONTACT_IDS_PATH,
          {"id" => @id, "vidOffset" => offset, "count" => limit}
        )

        [response["vids"], response["vidOffset"], response["hasMore"]]
      end
    end

    def remove_contact(contact)
      self.class.remove_contact(@id, contact.to_i)
    end
  end
end
