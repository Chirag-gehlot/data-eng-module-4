with trips_with_id as (

    select
        *,
        -- This is a artificially generated unique identifier when there is no reliable natural primary key available.
        {{ dbt_utils.generate_surrogate_key([
            'vendorid',
            'pickup_locationid',
            'dropoff_locationid',
            'pickup_datetime',
            'dropoff_datetime',
            'trip_distance',
            'fare_amount',
        ]) }} as trip_id
    from {{ref("int_trips_union")}}

),

deduplicated as (

    select *
    from trips_with_id
    qualify row_number() over (
        partition by trip_id
        order by pickup_datetime
    ) = 1

)

select *
from deduplicated
