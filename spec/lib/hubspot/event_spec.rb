describe Hubspot::Event do
  let(:portal_id) { '62515' }
  before { Hubspot.configure(hapikey: 'demo', portal_id: portal_id) }

  describe '.complete' do
    let(:event_id) { '000000001625' }
    let(:email) { 'testingapis@hubspot.com' }
    subject { described_class.complete(event_id, email) }

    it 'sends a request to complete the event' do

      url = "https://track.hubspot.com/v1/event?_n=#{event_id}&_a=#{portal_id}&email=#{CGI.escape email}"
      http_response = mock('http_response')
      http_response.success? { true }
      mock(Hubspot::EventConnection).get(url, body: nil) { http_response }

      expect(subject).to be true
    end
  end
end
