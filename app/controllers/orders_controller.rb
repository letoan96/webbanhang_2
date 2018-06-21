class OrdersController < ApplicationController
  require 'httparty'
  before_action :logged_in_user, only: %i[index show new create]
  before_action :user_is_admin, only: %i[destroy edit]
  before_action :cart_is_empty, only: %i[new create]

  def index
    @orders = Order.all
    if params[:search]
      @orders = Order.search(params[:search]).order('created_at ASC').paginate(page: params[:page], per_page: 5)
    else
      @orders = @orders.order('created_at ASC').paginate(page: params[:page], per_page: 5)
    end
  end

  def show
    @order = Order.find(params[:id])
  end

  def new
    @order = Order.new
    @cart = @current_cart
  end

  def create

    @order = Order.new(order_params)
    @order.update(user_id: @current_user.id)
    @current_cart.line_items.each do |item|
      item.cart_id = nil
      item.order_id = @order.id
      item.save
      @order.line_items << item
    end

    @order.save
    items = LineItem.where(:order_id => @order.id).pluck(:product_id)
    details = Product.where(:id => items).pluck(:name).join(' + ')
    address = @order.address
    details = "Don hang cua ban da duoc dat thanh cong. Don hang bao gom " + details + " .Dia chi nhan hang: " +  address + ". Chung toi se giao hang trong vong 24h."
    send_sms_confirmation(current_user.phone_number, details )
    Cart.destroy(session[:cart_id])
    session[:cart_id] = nil
    redirect_to orders_path
    # byebug
  end

  def send_sms_confirmation(phone_number, details)

    url = 'http://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_get?Phone='+ phone_number +'&Content='+ details +'&ApiKey=8E77994077AE93003FDF0B703165AB&SecretKey=7DDF57E604AB3C1468BFF870F64BFE&SmsType=3'
    options = { body:
        {
          Phone: phone_number,
          Content: details,
          APIKEY: '8E77994077AE93003FDF0B703165AB',
          SecretKey: '7DDF57E604AB3C1468BFF870F64BFE',
          SMSTYPE: 3
        }
      }
      result = HTTParty.get(url)
      puts result 
  end
  # def destroy
  #   respond_to do |format|
  #     if @order.destroy!
  #      format.html { redirect_to products_url }
  #      format.json { head :no_content }
  #      flash[:info] = 'Order was successfully destroyed.'
  #     else
  #       flash[:info] = 'Error destroying the order'
  #     end
  #   end
  # end

  def destroy
    @order = Order.find(params[:id])
    @order.destroy
    respond_to do |format|
      format.html { redirect_to orders_path }
      format.json { head :no_content }
      flash[:info] = 'Order was successfully destroyed.'
    end
  end

  def edit
    @order = Order.find(params[:id])
  end

  def update
     @order = Order.find(params[:id])
     @order.update(order_params)
     redirect_to orders_path
  end

  def cart_is_empty
    if @current_cart.line_items.empty?
      store_location
      flash[:danger] = 'You cart is empty!'
      redirect_to cart_path(@current_cart)
    end
  end

  private

  def order_params
    params.require(:order).permit(:user_id, :pay_method, :description, :address)
  end
end
