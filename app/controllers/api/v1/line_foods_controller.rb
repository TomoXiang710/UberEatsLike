module Api
  module V1
    class LineFoodsController < ApplicationController
      before_action :set_food, only: %i[create replace]

      def index
        # activeな仮注文レコードを取得
        line_foods = LineFood.active
        if line_foods.exists?
          render json: {
            line_foods_ids: line_foods.map { |line_food| line_food.id },
            restaurant: line_foods[0].restaurant,
            count: line_foods.sum { ||line_food| line_food.count },
            amount: line_foods.sum { ||line_food| line_food.total_amount }
          }
        else
          render json: {}, status: :no_content
        end
      end


      def create
        # 他店舗の仮注文があったらエラーを返す
        if LineFood.active.other_restaurant(@ordered_food.restaurant.id).exists?
          return render json: {
            # 複数の仮注文店舗が見つかった場合、最初の1件のみで良い
            existing_restaurant: LineFood.other_restaurant(@ordered_food.restaurant.id).first.restaurant.name,
            new_restaurant: Food.find(params[:food_id]).restaurant.name
          }, status: :not_acceptable
        end
        
        set_line_food(@ordered_food)

        if @line_food.save
          render json: {
            line_food: @line_food
          }, status: :created
        else
          render json: {}, status: :internal_server_error
        end
      end

      def replace
        LineFood.active.other_restaurant(@ordered_food.restaurant.id).each do |line_food|
          line_food.update_attribute(:active, false)
        end

        set_line_food(@ordered_food)

        if @line_food.save
          render json: {
            line_food: @line_food
          }, status: :created
        else
          render json: {}, status: :internal_server_error
        end
      end

      private

      def set_food
        @ordered_food = Food.find(params[:food_id])
      end

      def set_line_food(ordered_food)
        if ordered_food.line_food.present?
          @line_food = ordered_food.line_food
          @line_food.attributes = {
            count: ordered_food.line_food.count + params[:count]
            active: true
          }
        else
          @line_food = ordered_food.build_line_food(
            count: params[:count],
            restaurant: ordered_food.restaurants,
            active: true
          )
        end
      end
    end
  end
end