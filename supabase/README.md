# Bemo Supabase Database

This directory contains the Supabase database schema, migrations, and configuration for the Bemo learning app.

## 🏗️ Database Architecture

The database follows a multi-tenant architecture with Row Level Security (RLS) to ensure data isolation between families:

- **parent_profiles**: Maps Supabase auth users to Apple Sign-In users
- **child_profiles**: Individual child profiles belonging to authenticated parents  
- **learning_events**: All learning activities and achievements for analytics
- **game_sessions**: Gaming sessions for time-based analytics and progress tracking

## 🔐 Security Model

### Row Level Security (RLS)
All tables have RLS enabled with policies ensuring:
- Parents can only access their own data and their children's data
- No cross-family data access is possible
- Server-side enforcement prevents client-side security bypasses

### Key Security Features
- Apple Sign-In integration with Supabase Auth
- Automatic user filtering via RLS policies
- Secure helper functions for complex operations
- Data retention policies (no deletion of analytics data)

## 📁 Migration Files

### `20240101000000_initial_schema.sql`
- Creates core tables with proper relationships
- Adds constraints and indexes for performance
- Sets up automatic timestamp updating

### `20240101000001_row_level_security.sql`  
- Enables RLS on all tables
- Creates comprehensive security policies
- Adds helper functions for RLS operations

### `20240101000002_helper_functions.sql`
- Analytics functions for learning progress
- Safe XP update functions
- Session management functions
- Aggregated views for dashboard data

### `20240101000003_realtime_subscriptions.sql`
- Enables realtime updates for iOS app
- Custom notification functions
- Automatic triggers for live progress tracking

## 🚀 Local Development Setup

1. **Install Supabase CLI**:
   ```bash
   npm install -g supabase
   ```

2. **Initialize local development**:
   ```bash
   supabase start
   ```

3. **Apply migrations**:
   ```bash
   supabase db reset
   ```

4. **Access local dashboard**:
   - Studio: http://127.0.0.1:54323
   - API: http://127.0.0.1:54321
   - Database: postgresql://postgres:postgres@127.0.0.1:54322/postgres

## 📊 Key Functions

### Analytics Functions
- `get_child_learning_summary(child_id)`: Comprehensive learning stats
- `get_recent_learning_events(child_id, limit)`: Recent activity feed
- `get_daily_learning_stats(child_id, date_range)`: Daily progress tracking

### Data Management Functions  
- `record_learning_event()`: Creates events and updates XP atomically
- `start_game_session()` / `end_game_session()`: Session lifecycle management
- `update_child_xp()`: Safe XP updates with validation

### Realtime Functions
- `broadcast_learning_milestone()`: Custom milestone notifications
- `broadcast_xp_update()`: XP change notifications
- Automatic triggers for live progress updates

## 🔄 iOS Integration Pattern

The database is designed to work seamlessly with the iOS app's MVVM-S architecture:

1. **Authentication**: Apple Sign-In → Supabase Auth → RLS user context
2. **Profile Sync**: Local UserDefaults ↔ Supabase child_profiles table
3. **Learning Events**: Game actions → `record_learning_event()` → Analytics
4. **Realtime Updates**: Database changes → Realtime subscriptions → iOS UI updates

## 📈 Analytics Data Flow

```
iOS Game Engine → Learning Event → XP Update → Realtime Broadcast → Parent Dashboard
                     ↓
                Analytics Tables → Daily/Weekly Reports → Progress Tracking
```

## 🛡️ RLS Policy Examples

**Child Profile Access**:
```sql
-- Parents can only see their own children
CREATE POLICY "Parents can view own children" 
ON child_profiles FOR SELECT 
USING (auth.uid() = parent_user_id);
```

**Learning Events Access**:
```sql  
-- Parents can only see events for their children
CREATE POLICY "Parents can view children learning events" 
ON learning_events FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM child_profiles 
    WHERE child_profiles.id = learning_events.child_profile_id 
    AND child_profiles.parent_user_id = auth.uid()
  )
);
```

## 🚨 Important Security Notes

- Never expose the `service_role` key in client applications
- Always use the `anon` key for client-side connections
- RLS policies automatically filter all queries based on `auth.uid()`
- Test all policies thoroughly in development before production deployment
- Learning events and sessions are never deleted (audit trail preservation)

## 📱 Realtime Subscriptions

The iOS app can subscribe to realtime updates for:
- Child profile changes (XP updates, preference changes)
- Learning events (achievements, milestones)  
- Game session completion
- Custom milestone broadcasts

Example iOS subscription:
```swift
let channel = supabase.realtime.channel("child-progress")
  .on("postgres_changes", filter: "child_profiles:parent_user_id=eq.\(userID)") { message in
    // Handle realtime profile updates
  }
```

## 🔧 Maintenance

- Monitor slow query logs for performance optimization
- Regularly review RLS policies for security compliance
- Archive old learning events if storage becomes a concern
- Update analytics functions based on new app features

## 📞 Support

For questions about the database schema or RLS implementation, refer to:
- [Supabase RLS Documentation](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [PostgreSQL RLS Guide](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- Bemo app architecture documentation in `/Docs/architecture.md`