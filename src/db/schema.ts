import { integer, pgTable, varchar, timestamp } from "drizzle-orm/pg-core";

const createdAt = timestamp().notNull().defaultNow();
const updatedAt = timestamp().notNull().defaultNow().$onUpdate(() => new Date());

// ユーザー情報を格納するテーブル
// Hello World
// yeah!
export const usersTable = pgTable("users", {
  id: integer().primaryKey().generatedAlwaysAsIdentity(),
  // 名前
  // 255文字までの文字列
  name: varchar({ length: 255 }).notNull(),
  // 年齢
  age: integer().notNull(),
  // メールアドレス
  email: varchar({ length: 255 }).notNull().unique(),
  createdAt,
  updatedAt,
});
