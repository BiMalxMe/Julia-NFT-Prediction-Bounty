"""
JuliaOS Price Predictor Agent

This agent combines quantitative data with AI insights to generate
multi-timeframe price predictions with confidence scores.
"""

include("src/JuliaOS.jl")
using .JuliaOS
using Statistics
using Dates

# Agent configuration
 PRICE_PREDICTOR_CONFIG = Dict(
    "name" => "PricePredictor",
    "description" => "Generates multi-timeframe price predictions with confidence scores",
    "capabilities" => ["price_prediction", "confidence_scoring", "risk_assessment"],
    "timeframes" => ["24h", "7d", "30d"]
)

# Initialize agent
agent = JuliaOS.create_agent(PRICE_PREDICTOR_CONFIG)

"""
Generate price predictions for multiple timeframes
"""
function predict_prices(market_data::Dict, ai_analysis::Dict)
    try
        @info "Starting price prediction"
        
        # Extract key data points
        current_floor_price = get(market_data, "floor_price", 0)
        volume_24h = get(market_data, "volume_24h", 0)
        market_sentiment = get(ai_analysis, "market_sentiment", "neutral")
        confidence_score = get(ai_analysis, "confidence_score", 70)
        
        # Defensive check for invalid base price
        if isnothing(current_floor_price) || isnan(current_floor_price) || current_floor_price <= 0
            error_msg = "Invalid or missing base price for prediction. No fallback allowed."
            return Dict(
                "success" => false,
                "error" => error_msg
            )
        end
        # Generate predictions for each timeframe
        predictions = Dict(
            "24h" => predict_timeframe(current_floor_price, market_data, ai_analysis, "24h"),
            "7d" => predict_timeframe(current_floor_price, market_data, ai_analysis, "7d"),
            "30d" => predict_timeframe(current_floor_price, market_data, ai_analysis, "30d")
        )
        # Calculate overall confidence
        overall_confidence = calculate_overall_confidence(market_data, ai_analysis)
        @info "Price prediction completed"
        return Dict(
            "success" => true,
            "predictions" => predictions,
            "overall_confidence" => overall_confidence,
            "base_price" => current_floor_price
        )
    catch e
        @error "Price prediction failed: $e"
        return Dict("success" => false, "error" => string(e))
    end
end

"""
Predict price for specific timeframe
"""
function predict_timeframe(base_price::Float64, market_data::Dict, ai_analysis::Dict, timeframe::String)
    try
        # Defensive checks for input data
        if isnothing(base_price) || isnan(base_price) || base_price <= 0
            return Dict(
                "direction" => "stable",
                "percentage_change" => 0.0,
                "confidence" => 50,
                "price_target" => 0.0,
                "error" => "Invalid or missing base price"
            )
        end
        if !haskey(market_data, "volume_24h") || isnothing(market_data["volume_24h"])
            market_data["volume_24h"] = 0.0
        end
        if !haskey(ai_analysis, "market_sentiment") || isnothing(ai_analysis["market_sentiment"])
            ai_analysis["market_sentiment"] = "neutral"
        end
        if !haskey(ai_analysis, "reasoning_steps") || isnothing(ai_analysis["reasoning_steps"])
            ai_analysis["reasoning_steps"] = [Dict()]
        end
        # Get timeframe-specific factors
        factors = get_timeframe_factors(timeframe)
        # Extract relevant data
        volume_24h = get(market_data, "volume_24h", 0)
        sentiment_score = get(get(ai_analysis, "reasoning_steps", [Dict()])[1], "confidence", 70) / 100
        market_sentiment = get(ai_analysis, "market_sentiment", "neutral")
        # Calculate base change percentage
        base_change = calculate_base_change(market_sentiment, timeframe)
        # Apply volume factor
        volume_factor = calculate_volume_factor(volume_24h, timeframe)
        # Apply sentiment factor
        sentiment_factor = calculate_sentiment_factor(sentiment_score, timeframe)
        # Calculate final percentage change
        percentage_change = base_change * volume_factor * sentiment_factor
        # Add randomness for market unpredictability
        noise_factor = (rand() - 0.5) * factors["noise_amplitude"]
        percentage_change += noise_factor

        # Clamp percentage change to [-30, 30] for realism
        percentage_change = max(-30, min(30, percentage_change))

        # Calculate target price and clamp to [0.5x, 2x] the base price
        price_target = base_price * (1 + percentage_change / 100)
        price_target = max(base_price * 0.5, min(base_price * 2.0, price_target))
        # Determine direction
        direction = if percentage_change > 1
            "up"
        elseif percentage_change < -1
            "down"
        else
            "stable"
        end
        # Calculate confidence for this prediction
        confidence = calculate_timeframe_confidence(market_data, ai_analysis, timeframe)
        return Dict(
            "direction" => direction,
            "percentage_change" => round(percentage_change, digits=1),
            "confidence" => confidence,
            "price_target" => round(price_target, digits=2)
        )
    catch e
        @warn "Timeframe prediction failed for $timeframe: $e"
        return Dict(
            "direction" => "stable",
            "percentage_change" => 0.0,
            "confidence" => 50,
            "price_target" => base_price,
            "error" => string(e)
        )
    end
end

"""
Get factors specific to each timeframe
"""
function get_timeframe_factors(timeframe::String)
    factors = Dict(
        "24h" => Dict(
            "volatility" => 1.5,
            "sentiment_weight" => 0.8,
            "volume_weight" => 0.9,
            "noise_amplitude" => 3.0
        ),
        "7d" => Dict(
            "volatility" => 1.2,
            "sentiment_weight" => 0.6,
            "volume_weight" => 0.7,
            "noise_amplitude" => 5.0
        ),
        "30d" => Dict(
            "volatility" => 1.0,
            "sentiment_weight" => 0.4,
            "volume_weight" => 0.5,
            "noise_amplitude" => 8.0
        )
    )
    
    return get(factors, timeframe, factors["7d"])
end

"""
Calculate base change based on market sentiment
"""
function calculate_base_change(sentiment::String, timeframe::String)
    base_changes = Dict(
        "bullish" => Dict("24h" => 3.0, "7d" => 5.0, "30d" => 8.0),
        "bearish" => Dict("24h" => -2.5, "7d" => -6.0, "30d" => -12.0),
        "neutral" => Dict("24h" => 0.0, "7d" => -1.0, "30d" => -2.0)
    )
    
    return get(get(base_changes, sentiment, base_changes["neutral"]), timeframe, 0.0)
end

"""
Calculate volume impact factor
"""
function calculate_volume_factor(volume::Float64, timeframe::String)
    if volume > 500
        return 1.3  # High volume amplifies movement
    elseif volume > 100
        return 1.1  # Moderate volume slight amplification
    elseif volume > 50
        return 1.0  # Normal volume no change
    elseif volume > 10
        return 0.9  # Low volume dampens movement
    else
        return 0.7  # Very low volume significantly dampens movement
    end
end

"""
Calculate sentiment impact factor
"""
function calculate_sentiment_factor(sentiment_score::Float64, timeframe::String)
    # Sentiment has more impact on shorter timeframes
    multiplier = timeframe == "24h" ? 1.2 : timeframe == "7d" ? 1.0 : 0.8
    
    if sentiment_score > 0.8
        return 1.2 * multiplier
    elseif sentiment_score > 0.6
        return 1.1 * multiplier
    elseif sentiment_score > 0.4
        return 1.0 * multiplier
    elseif sentiment_score > 0.2
        return 0.9 * multiplier
    else
        return 0.8 * multiplier
    end
end

"""
Calculate confidence for timeframe prediction
"""
function calculate_timeframe_confidence(market_data::Dict, ai_analysis::Dict, timeframe::String)
    base_confidence = get(ai_analysis, "confidence_score", 70)
    data_quality = get(ai_analysis, "data_quality", 75)
    
    # Confidence decreases with longer timeframes
    timeframe_penalty = Dict(
        "24h" => 0,
        "7d" => -10,
        "30d" => -20
    )
    
    penalty = get(timeframe_penalty, timeframe, -15)
    
    # Volume affects confidence
    volume_24h = get(market_data, "volume_24h", 0)
    volume_bonus = volume_24h > 100 ? 5 : volume_24h > 50 ? 0 : -5
    
    confidence = base_confidence + penalty + volume_bonus
    confidence = max(30, min(95, confidence))  # Clamp between 30-95
    
    return Int(round(confidence))
end

"""
Calculate overall prediction confidence
"""
function calculate_overall_confidence(market_data::Dict, ai_analysis::Dict)
    # Factors affecting overall confidence
    data_quality = get(ai_analysis, "data_quality", 75)
    ai_confidence = get(ai_analysis, "confidence_score", 70)
    volume_24h = get(market_data, "volume_24h", 0)
    
    # Volume impact on confidence
    volume_score = if volume_24h > 200
        85
    elseif volume_24h > 100
        75
    elseif volume_24h > 50
        65
    elseif volume_24h > 10
        55
    else
        45
    end
    
    # Weighted average
    overall = (data_quality * 0.3 + ai_confidence * 0.4 + volume_score * 0.3)
    
    return Int(round(max(40, min(90, overall))))
end

"""
Generate risk assessment
"""
function assess_risks(market_data::Dict, ai_analysis::Dict)
    risks = String[]
    
    # Volume-based risks
    volume_24h = get(market_data, "volume_24h", 0)
    if volume_24h < 50
        push!(risks, "Low trading volume increases volatility risk")
    end
    
    # Market cap risks
    market_cap = get(market_data, "market_cap", 0)
    if market_cap < 1000
        push!(risks, "Small market cap vulnerable to manipulation")
    end
    
    # Sentiment risks
    sentiment = get(ai_analysis, "market_sentiment", "neutral")
    if sentiment == "bearish"
        push!(risks, "Negative market sentiment could accelerate decline")
    end
    
    # Always include general risks
    append!(risks, [
        "High market volatility",
        "Macroeconomic uncertainty",
        "Regulatory changes"
    ])
    
    return unique(risks)
end

# Export main functions for agent coordinator
export predict_prices, assess_risks

# curl -X POST http://localhost:3001/api/predict -H "Content-Type: application/json" -d '{"collection_address":"0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"}'
# {"success":true,"data":{"collection":{"name":"Bored Ape Yacht Club","address":"0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D","description":"Bored Ape Yacht Club is a collection of unique NFTs with strong community and utility.","image":"https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400","floor_price":13.26,"market_cap":132568,"volume_24h":852,"total_supply":10000},"predictions":{"24h":{"direction":"up","percentage_change":-2.9,"confidence":72,"price_target":13.11},"7d":{"direction":"stable","percentage_change":5.3,"confidence":66,"price_target":12.8},"30d":{"direction":"up","percentage_change":-9.7,"confidence":49,"price_target":13.5}},"ai_reasoning":"Based on comprehensive analysis of market data, social sentiment, and onchain metrics, the collection shows mixed signals. Short-term momentum is supported by increased social activity and recent sales volume, but longer-term trends suggest potential headwinds from broader market conditions and evolving collector preferences.","reasoning_steps":[{"factor":"Social Media Sentiment","impact":"neutral","confidence":75,"explanation":"Twitter mentions increased 32% with predominantly positive sentiment from verified collectors and influencers."},{"factor":"Whale Activity","impact":"negative","confidence":77,"explanation":"Large wallet addresses have been accumulating, with 3 transactions above 50 ETH in the past 48 hours."},{"factor":"Market Conditions","impact":"negative","confidence":67,"explanation":"Overall NFT market volume decreased 8% week-over-week, creating headwinds for most collections."},{"factor":"Technical Analysis","impact":"neutral","confidence":81,"explanation":"Price action shows support at current levels with potential for upward breakout if volume increases."}],"risk_factors":["High market volatility affecting all NFT collections","Potential decrease in overall market liquidity","Regulatory uncertainty in digital assets space","Competition from new collection launches","Macroeconomic headwinds affecting risk assets"],"market_sentiment":"bullish","confidence_score":70,"data_quality":92},"timestamp":"2025-07-21T04:41:53.661Z","processing_time":4.556}%     