with taxi_zone_lookup as(
    select * from {{ref("taxi_zone_lookup")}}
),

rename as(
    select 
        LocationID as location_id,
        Borough as borough,
        Zone as zone,
        service_zone
    from taxi_zone_lookup 
)

select * from rename