# encoding: utf-8
require 'spec_helper'
require 'base64'

describe 'Ably::Rest Message Encoder' do
  let(:default_client_options) { { api_key: api_key, environment: environment } }
  let(:client)                 { Ably::Rest::Client.new(default_client_options.merge(protocol: protocol)) }
  let(:channel_options)        { {} }
  let(:channel)                { client.channel('test', channel_options) }
  let(:response)               { instance_double('Faraday::Response', status: 201) }

  let(:cipher_params)          { { key: random_str, algorithm: 'aes', mode: 'cbc', key_length: 128 } }
  let(:crypto)                 { Ably::Util::Crypto.new(cipher_params) }

  let(:utf_8_data)             { random_str.encode(Encoding::UTF_8) }
  let(:binary_data)            { MessagePack.pack(random_str).encode(Encoding::ASCII_8BIT) }
  let(:json_data)              { { 'key' => random_str } }

  after do
    channel.publish 'event', published_data
  end

  def on_publish
    expect(client).to receive(:post) do |url, message|
      yield(message['encoding'], message['data'])
    end.and_return(response)
  end

  def decrypted(payload, options = {})
    payload = Base64.decode64(payload) if options[:base64]
    crypto.decrypt(payload)
  end

  context 'with binary transport protocol' do
    let(:protocol) { :msgpack }

    context 'without encryption' do
      context 'with UTF-8 data' do
        let(:published_data) { utf_8_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to be_nil
            expect(encoded_data).to eql(published_data)
          end
        end
      end

      context 'with binary data' do
        let(:published_data) { binary_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to be_nil
            expect(encoded_data).to eql(published_data)
          end
        end
      end

      context 'with JSON data' do
        let(:published_data) { json_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('json')
            expect(encoded_data).to eql(JSON.dump(published_data))
          end
        end
      end
    end

    context 'with encryption' do
      let(:channel_options) { { encrypted: true, cipher_params: cipher_params } }

      context 'with UTF-8 data' do
        let(:published_data) { utf_8_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('utf-8/cipher+aes-128-cbc')
            expect(decrypted(encoded_data)).to eql(published_data)
          end
        end
      end

      context 'with binary data' do
        let(:published_data) { binary_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('cipher+aes-128-cbc')
            expect(decrypted(encoded_data)).to eql(published_data)
          end
        end
      end

      context 'with JSON data' do
        let(:published_data) { json_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('json/utf-8/cipher+aes-128-cbc')
            expect(decrypted(encoded_data)).to eql(JSON.dump(published_data))
          end
        end
      end
    end
  end

  context 'with text transport protocol' do
    let(:protocol) { :json }

    context 'without encryption' do
      context 'with UTF-8 data' do
        let(:published_data) { utf_8_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to be_nil
            expect(encoded_data).to eql(published_data)
          end
        end
      end

      context 'with binary data' do
        let(:published_data) { binary_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('base64')
            expect(Base64.decode64(encoded_data)).to eql(published_data)
          end
        end
      end

      context 'with JSON data' do
        let(:published_data) { json_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('json')
            expect(encoded_data).to eql(JSON.dump(published_data))
          end
        end
      end
    end

    context 'with encryption' do
      let(:channel_options) { { encrypted: true, cipher_params: cipher_params } }

      context 'with UTF-8 data' do
        let(:published_data) { utf_8_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('utf-8/cipher+aes-128-cbc/base64')
            expect(decrypted(encoded_data, base64: true)).to eql(published_data)
          end
        end
      end

      context 'with binary data' do
        let(:published_data) { binary_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('cipher+aes-128-cbc/base64')
            expect(decrypted(encoded_data, base64: true)).to eql(published_data)
          end
        end
      end

      context 'with JSON data' do
        let(:published_data) { json_data }

        it 'does not require an encoding' do
          on_publish do |encoding, encoded_data|
            expect(encoding).to eql('json/utf-8/cipher+aes-128-cbc/base64')
            expect(decrypted(encoded_data, base64: true)).to eql(JSON.dump(published_data))
          end
        end
      end
    end
  end
end
