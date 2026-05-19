const spider = @import("spider");

pub const config = spider.Config{
    .port = 3000,
    .host = "127.0.0.1",
    .views_dir = "./src",
    .layout = "layout",
    .static_dir = "./public",
    .env = .development,
    .workers = null,
};
