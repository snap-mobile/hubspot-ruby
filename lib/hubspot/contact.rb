class Hubspot::Contact < Hubspot::Resource
  self.id_field = "vid"
  self.update_method = "post"

  ALL_PATH                = '/contacts/v1/lists/all/contacts/all'
  CREATE_PATH             = '/contacts/v1/contact'
  CREATE_OR_UPDATE_PATH   = '/contacts/v1/contact/createOrUpdate/email/:email'
  DELETE_PATH             = '/contacts/v1/contact/vid/:id'
  FIND_PATH               = '/contacts/v1/contact/vid/:id/profile'
  FIND_BY_EMAIL_PATH      = '/contacts/v1/contact/email/:email/profile'
  FIND_BY_USER_TOKEN_PATH = '/contacts/v1/contact/utk/:token/profile'
  MERGE_PATH              = '/contacts/v1/contact/merge-vids/:id/'
  SEARCH_PATH             = '/contacts/v1/search/query'
  UPDATE_PATH             = '/contacts/v1/contact/vid/:id/profile'

  class << self
    def all(opts = {})
      Hubspot::PagedCollection.new(opts) do |options, offset, limit|
        response = Hubspot::Connection.get_json(
          ALL_PATH,
          options.merge("count" => limit, "vidOffset" => offset)
          )

        contacts = response["contacts"].map { |result| from_result(result) }
        [contacts, response["vid-offset"], response["has-more"]]
      end
    end

    def find_by_email(email)
      response = Hubspot::Connection.get_json(FIND_BY_EMAIL_PATH, email: email)
      from_result(response)
    end

    def find_by_user_token(token)
      response = Hubspot::Connection.get_json(FIND_BY_USER_TOKEN_PATH, token: token)
      from_result(response)
    end
    alias_method :find_by_utk, :find_by_user_token

    def create(email, properties = {})
      super(properties.merge("email" => email))
    end

    def create_or_update(email, properties = {})
      request = {
        properties: Hubspot::Utils.hash_to_properties(properties.stringify_keys, key_name: "property")
      }
      response = Hubspot::Connection.post_json(CREATE_OR_UPDATE_PATH, params: {email: email}, body: request)
      from_result(response)
    end

    def search(query, opts = {})
      Hubspot::PagedCollection.new(opts) do |options, offset, limit|
        response = Hubspot::Connection.get_json(
          SEARCH_PATH,
          options.merge(q: query, offset: offset, count: limit)
          )

        contacts = response["contacts"].map { |result| from_result(result) }
        [contacts, response["offset"], response["has-more"]]
      end
    end

    def merge(primary, secondary)
      Hubspot::Connection.post_json(
        MERGE_PATH,
        params: { id: primary.to_i, no_parse: true },
        body: { "vidToMerge" => secondary.to_i }
        )

      true
    end

    # Updates the properties of a contact
    # {https://developers.hubspot.com/docs/methods/contacts/update_contact}
    # @param params [Hash] hash of properties to update
    def update!(vid, params = {})
      query = {"properties" => Hubspot::Utils.hash_to_properties(params.stringify_keys!)}
      Hubspot::Connection.post_json(UPDATE_CONTACT_PATH, params: { contact_id: vid }, body: query)
    end

    attr_reader :properties, :vid, :is_new
    attr_reader :is_contact, :list_memberships

    def initialize(response_hash)
      props = response_hash['properties']
      @properties = Hubspot::Utils.properties_to_hash(props) unless props.blank?
      @is_contact = response_hash["is-contact"]
      @list_memberships = response_hash["list-memberships"] || []
      @vid = response_hash['vid']
    end

    def [](property)
      @properties[property]
    end

    def email
      @properties['email']
    end

    def utk
      @properties['usertoken']
    end

    def is_new=(val)
      @is_new = val
    end

    # Updates the properties of a contact
    # {https://developers.hubspot.com/docs/methods/contacts/update_contact}
    # @param params [Hash] hash of properties to update
    # @return [Hubspot::Contact] self
    def update!(params)
      self.class.update!(vid, params)
      @properties.merge!(params)
      self
    end

    # Archives the contact in hubspot
    # {https://developers.hubspot.com/docs/methods/contacts/delete_contact}
    # @return [TrueClass] true
    def destroy!
      Hubspot::Connection.delete_json(DESTROY_CONTACT_PATH, { contact_id: vid })
      @destroyed = true
    end

    def destroyed?
      !!@destroyed
    end
  end

  def name
    [firstname, lastname].compact.join(' ')
  end

  def merge(contact)
    self.class.merge(@id, contact.to_i)
  end
end
