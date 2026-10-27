// ═══════════════════════════════════════════════════════════════════════════
// mongo_shell_create_index.js
//
// Tạo 2dsphere index cho collection UserPlants — chạy trong Mongo Shell
//
// Cách chạy:
//   mongosh "mongodb+srv://..." --file mongo_shell_create_index.js
//   hoặc dán trực tiếp vào MongoDB Compass Shell / Atlas Query Console
// ═══════════════════════════════════════════════════════════════════════════

// 1. Chọn database
use("plant_vision_db");

// ── Index 1: 2dsphere đơn trên field location ────────────────────────────
//    Dùng cho $geoWithin / $near / $geoIntersects
db.UserPlants.createIndex(
  { "location": "2dsphere" },
  {
    name:       "location_2dsphere",
    background: true,   // Non-blocking build (Mongo < 4.2 legacy flag; mặc định ở 4.2+)
    sparse:     true,   // Bỏ qua doc không có field 'location' — tránh lỗi index
  }
);

print("✅  Index 'location_2dsphere' đã tạo (hoặc đã tồn tại).");

// ── Index 2: Compound (user_id ASC + 2dsphere) ───────────────────────────
//    Tối ưu truy vấn lọc cùng lúc user_id VÀ tọa độ.
//    Lưu ý: Compound index với 2dsphere chỉ được phép có 1 geo field.
db.UserPlants.createIndex(
  { "user_id": 1, "location": "2dsphere" },
  {
    name:       "user_id_location_2dsphere",
    background: true,
    sparse:     true,
  }
);

print("✅  Index 'user_id_location_2dsphere' đã tạo (hoặc đã tồn tại).");

// ── Kiểm tra kết quả ─────────────────────────────────────────────────────
print("\n📋  Danh sách index hiện tại:");
db.UserPlants.getIndexes().forEach(idx => {
  print(`  • ${idx.name}  →  key: ${JSON.stringify(idx.key)}`);
});

// ── Explain query kiểm tra index có được dùng không ──────────────────────
//    (Bỏ comment dòng dưới khi cần debug explain plan)
//
// const plan = db.UserPlants.find({
//   user_id: "REPLACE_WITH_REAL_USER_ID",
//   location: {
//     $geoWithin: {
//       $geometry: {
//         type: "Polygon",
//         coordinates: [[
//           [105.8, 21.0], [106.0, 21.0],
//           [106.0, 21.1], [105.8, 21.1],
//           [105.8, 21.0]
//         ]]
//       }
//     }
//   }
// }).explain("executionStats");
// printjson(plan.queryPlanner.winningPlan);

print("\n🎉  Hoàn tất!");
