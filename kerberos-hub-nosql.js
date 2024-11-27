use Kerberos;

db.subscriptions.insertMany([{
    "_id" : ObjectId("57e1011e3178aa6c5cc774d1"),
    "name" : "default",
    "stripe_id" : "sub_9ECyjjMz3R7etK",
    "stripe_plan" : "enterprise",
    "quantity" : 1,
    "trial_ends_at" : null,
    "ends_at" : null,
    "user_id" : "57e1011e3178aa6c5cc774d1",
    "updated_at" : ISODate("2021-04-27T09:45:30.169Z"),
    "created_at" : ISODate("2016-09-20T09:35:03.448Z"),
    "stripe_status" : "active"
}]);

db.users.insertMany([{
    "_id" : ObjectId("57e1011e3178aa6c5cc774d1"),
    "username" : "youruser",
    "email" : "your@email.com",
    "password" : "$2a$10$XS8XdjzgUCbvGHgt9KVHEuDBnmu1bfAhT/WFxcHCubJtHud8O8vSC",
    "isActive" : NumberLong(1),
    "registerToken" : "",
    "timezone" : "Europe/Brussels",
    "updated_at" : ISODate("2020-06-14T05:01:35.000Z"),
    "created_at" : ISODate("2016-09-20T09:27:58.811Z"),
    "amazon_secret_access_key" : "K6rRLBI1xxxCk3C1H",
    "amazon_access_key_id" : "AKIAxxxxxxG5Q",
    "card_brand" : "MasterCard",
    "card_last_four" : "6888",
    "sequence_first" : 1510657836,
    "card_status" : "ok",
    "card_status_message" : null,
    "role" : "owner",
    "admin" : true,
    "google2fa_enabled" : false
}]);

db.settings.insertMany([
    {
        "_id" : ObjectId("5a43fa12d885eb7da57046b3"),
        "key" : "sequence",
        "map" : {
            "timeBetween" : NumberInt(60)
        }
    },
    {
        "_id" : ObjectId("5a4d3a6bd885eb7da5e6b297"),
        "key" : "throttler",
        "map" : {
            "waitingTime" : NumberInt(60)
        }
    },
    {
        "_id" : ObjectId("5a53d0a0d885eb7da53ed5a6"),
        "key" : "analysis",
        "map" : {
            "waitingTime" : NumberInt(15)
        }
    },
    {
        "_id" : ObjectId("5a72c509e17699d18ada9154"),
        "key" : "plan",
        "map" : {
            "basic" : {
                "level" : NumberInt(1),
                "uploadLimit" : NumberInt(100),
                "videoLimit" : NumberInt(100),
                "usage" : NumberInt(500),
                "analysisLimit" : NumberInt(0),
                "dayLimit" : NumberInt(3)
            },
            "premium" : {
                "level" : NumberInt(2),
                "uploadLimit" : NumberInt(500),
                "videoLimit" : NumberInt(500),
                "usage" : NumberInt(1000),
                "analysisLimit" : NumberInt(0),
                "dayLimit" : NumberInt(7)
            },
            "gold" : {
                "level" : NumberInt(3),
                "uploadLimit" : NumberInt(1000),
                "videoLimit" : NumberInt(1000),
                "usage" : NumberInt(3000),
                "analysisLimit" : NumberInt(1000),
                "dayLimit" : NumberInt(30)
            },
            "business" : {
                "level" : NumberInt(4),
                "uploadLimit" : NumberInt(99999999),
                "videoLimit" : NumberInt(99999999),
                "usage" : NumberInt(10000),
                "analysisLimit" : NumberInt(1000),
                "dayLimit" : NumberInt(30)
            },
            "enterprise" : {
                "level" : NumberInt(5),
                "uploadLimit" : NumberInt(99999999),
                "videoLimit" : NumberInt(99999999),
                "usage" : NumberInt(99999999),
                "analysisLimit" : NumberInt(5000),
                "dayLimit" : NumberInt(30)
            }
        }
    },
    { 
        "_id" : ObjectId("63f346ec64011a574161cf99"), 
        "key" : "classifications", 
        "map" : {
            "objects" : [
                {
                    "text" : "Car", 
                    "value" : "car", 
                    "icon" : "car"
                }, 
                {
                    "text" : "Person", 
                    "value" : "pedestrian", 
                    "icon" : "pedestrian"
                }
            ]
        }
    }
]);