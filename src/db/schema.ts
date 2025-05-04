import { integer, pgTable, varchar, timestamp } from "drizzle-orm/pg-core";

const createdAt = timestamp().notNull().defaultNow();
const updatedAt = timestamp().notNull().defaultNow().$onUpdate(() => new Date());

export const usersTable = pgTable("users", {
  id: integer().primaryKey().generatedAlwaysAsIdentity(),
  name: varchar({ length: 255 }).notNull(),
  age: integer().notNull(),
  email: varchar({ length: 255 }).notNull().unique(),
  createdAt,
  updatedAt,
});
