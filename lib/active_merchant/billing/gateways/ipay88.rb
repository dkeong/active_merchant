module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
     class Ipay88Gateway < Gateway
          API_HOST = 'www.mobile88.com'
          #self.live_url = 'https://' + API_HOST + '/ePayment/enquiry.asp'
          self.live_url = 'https://' + API_HOST + '/epayment/entry_para.asp'
    
          self.default_currency = 'MYR'
          self.money_format = :cents
          self.supported_cardtypes = [:visa, :master]
          self.supported_countries = ['MY']
          self.homepage_url = 'http://www.mobile88.com/'
          self.display_name = 'iPay'

          # login: merchant number
          # password: referrer url (for authorize authentication)
          def initialize(options = {})
               requires!(options, :login, :password)
               #Ipay.options = {
               #  :merchant_key       => options[:login],
               #  :merchant_password  => options[:password],
               #}
               super
          end

          def authorize(money, options = {})
               post = {}
       
               add_amount(post, money, options)
               add_invoice(post, options)
               add_details_data(post, options)
       
               commit(money, post)
          end

          def purchase(money, options={})
               post = {}
               
               add_amount(post, money, options)
               add_invoice(post, options)
               add_details_data(post, options)
               add_return_url(post, options)
               
               commit(money, post)
          end

          def capture(money, authorization, options = {})
               post = {}
       
               add_reference(post, authorization)
               add_amount_without_currency(post, money)
       
               commit(money, post)
          end

          def void(identification, options = {})
               post = {}
       
               add_reference(post, identification)
       
               commit(nil, post)
          end

          def refund(money, identification, options = {})
               post = {}
       
               add_amount_without_currency(post, money)
               add_reference(post, identification)
       
               commit(nil, post)
          end

          def credit(money, identification, options = {})
               deprecated CREDIT_DEPRECATION_MESSAGE
               refund(money, identification, options)
          end
    
          private
    
          def add_amount(post, money, options)
               post[:Amount]   = amount(money)
               post[:Currency] = 'MYR'
          end
    
          def add_amount_without_currency(post, money)
               post[:Amount] = amount(money)
          end
          
    
          def add_invoice(post, options)
               post[:RefNo] = options[:OrderID]
          end
          
          def add_return_url(post, options)
               post[:ResponseURL] = options[:return_url]
          end
          
          def add_details_data(post, options)
               post[:UserName] = options[:customer]
               post[:UserEmail] = options[:email]
               post[:UserContact] = options[:phone]
               post[:ProdDesc] = options[:description]
          end
          
          def post_data(post, parameters = {})
               params = {}
               
               post[:MerchantCode] = @options[:login]
               params[:MerchantKey]   = @options[:password]
               post[:PaymentId] = '2'
               post[:Lang] = 'UTF-8'
               
               #Generate Signature  => $MerchantKey.$MerchantCode.$myCase->invoice_id.get_ttlamount($myamount).$currency;
               hash_data   = generate_hash_data(params, post)
               post[:Signature] = hash_data
               #puts hash_data
               
               #post.merge(parameters).map {|key,value| "#{key}=#{CGI.escape(value.to_s)}"}.join("&")
          end
          
          def generate_hash_data(params, post)
               post[:Amount] = getamount_in_cents(post[:Amount]);
               data = [post[:MerchantCode],params[:MerchantKey],format_order_id(post[:RefNo]),post[:Amount],post[:Currency]].join
               Base64.encode64(Digest::SHA1.digest("#{data}")).strip
          end
          
          def getamount_in_cents(money)
               sprintf("%.2f", money.to_f/100)
               money.gsub!(/\D/, "") 
          end
          
          # OrderId field must be A-Za-z0-9_ format and max 36 char
          def format_order_id(order_id)
               order_id.to_s.gsub(/[^A-Za-z0-9_]/, '')[0...36]
          end
    
          def commit(money, parameters)
               #response = parse(ssl_post(self.live_url, post_data(parameters)) )
               patch_post_request(parameters)
               
               #Response.new(response[:status] == '1', response[:message], response,
               #     :auth_code => response[:auth_code],
               #     :card_type => response[:card_type],
               #     :trans_type => response[:trans_type],
               #     :status => response[:status],
               #     :avs => response[:avs],
               #     :trans_id => response[:trans_id],
               #     :cvv2 => response[:cvv2],
               #     :message  => response[:message ],
               #)
  
          end
          
          def patch_post_request(parameters)
               url = URI.parse(self.live_url)
               post_data(parameters)
               
               #req = Net::HTTP::Post.new(url.path)
               #req.set_form_data({:tx => @subscription.tx, :at => IDENTITY_TOKEN, :cmd => "_notify-sync"})
               #sock = Net::HTTP.new(paypal_uri.host, 443)
               #sock.use_ssl = true
               #
               http = Net::HTTP.new(url.path, 80)
               req.set_form_data(url,{'MerchantCode' => 'M03228', "PaymentId" => "2", "RefNo" => "432841", "Amount" => "1" , "Currency" => "MYR", "ProdDesc" => "My Products", "Lang" => "UTF-8" , "UserName" => "Danny" , "UserEmail" => "danny@aspaccreative.com", "UserContact" => "0162770383" , "Signature" => "IuN7aEQewQaZNr/UYHa5QGJ2dPM=", "ResponseURL" => "http://localhost:3000/orders/1/b36017d777a3a69ff1fa9f5fd05e73f1/done?utm_nooverride=1"})
              
               sock = Net::HTTP.new(url.host, 443)
               sock.use_ssl = true
               sock.start do |http|
                     http.request(req)
               end
                              
               #case res
               #     when Net::HTTPSuccess, Net::HTTPRedirection
               #          puts "OK!"
               #     else
               #          res.value
               #end
          
               #puts req.body
               #res = Net::HTTP.post_form(uri, parameters)
               #puts res.body
          end
                
          def parse(body)
            result = {}
            pairs = body.split("&")
            pairs.each do |pair|
              a = pair.split("=")
              result[a[0].gsub(/^VP/,'').underscore.to_sym] = a[1]
            end
    
            result
          end
          
          def message_from(response)
            case response["Status"]
            when "1"
              "This transaction has been approved"
            when "0"
              "This transaction has been declined"
            else
              response["Status"]
            end
          end
    end
  end
end
