# Profile System Fix - Testing Checklist

## 🚀 Deployment Steps

### 1. Database Migration
```bash
# If not linked to your Supabase project:
supabase link --project-ref YOUR_PROJECT_REF

# Apply the cleanup migration:
supabase db push

# Verify migration applied successfully:
supabase db diff --use-remote
```

### 2. Clear Local Development Data (One-time)
```bash
# Clear simulator/device app data for fresh start
# In Xcode: Device -> Erase All Content and Settings
# Or delete app and reinstall
```

## 🧪 Testing Scenarios

### Pre-Testing Setup
- [ ] Sign out completely from the app
- [ ] Clear app data (delete and reinstall if needed)
- [ ] Verify Supabase project is clean of test data

### Test 1: New User Registration
- [ ] Open app for first time
- [ ] Sign in with Apple ID
- [ ] Create a child profile with name "TestChild1"
- [ ] **Expected**: Profile should be visible in profile selection
- [ ] **Check Database**: Verify profile exists in Supabase dashboard
- [ ] **Expected**: Only YOUR profiles should be visible, no "Rooshss" or other foreign profiles

### Test 2: Profile Persistence
- [ ] Create profile "TestChild1"
- [ ] Force quit app
- [ ] Reopen app
- [ ] **Expected**: "TestChild1" should still be available for selection
- [ ] **Check**: Profile should load without requiring re-creation

### Test 3: Multi-Profile Management
- [ ] Create second profile "TestChild2"  
- [ ] Switch between profiles
- [ ] **Expected**: Can select either profile
- [ ] **Expected**: Active profile changes correctly
- [ ] **Check Database**: Both profiles exist with correct parent_user_id

### Test 4: Sign Out and Sign In
- [ ] Create a profile
- [ ] Sign out completely  
- [ ] Sign back in with same Apple ID
- [ ] **Expected**: Previous profiles should be restored from database
- [ ] **Expected**: No foreign profiles should appear

### Test 5: Cross-User Isolation  
- [ ] Sign out
- [ ] Sign in with different Apple ID (if available)
- [ ] **Expected**: Should see empty profile list or different profiles
- [ ] **Expected**: Previous user's profiles should NOT be visible

### Test 6: Database Consistency
- [ ] Go to Supabase dashboard
- [ ] Check `child_profiles` table
- [ ] **Expected**: All profiles have correct `parent_user_id` matching authenticated user
- [ ] **Expected**: No profiles with `parent_user_id = '00000000-0000-0000-0000-000000000000'`

## 🔍 Known Issues to Verify Are Fixed

### ✅ Issue 1: Foreign Profiles Appearing
- [ ] **Before**: Could select "Rooshss" or other users' profiles
- [ ] **After**: Only profiles created by current user should appear

### ✅ Issue 2: Profiles Not Persisting to Database  
- [ ] **Before**: Profiles only stored locally in UserDefaults
- [ ] **After**: Profiles should persist to Supabase database

### ✅ Issue 3: Test Data Contamination
- [ ] **Before**: Emma/Lucas test profiles visible in production
- [ ] **After**: No test data should be visible in production environment

### ✅ Issue 4: Profile Sync Duplication
- [ ] **Before**: syncWithSupabase could create duplicate profiles
- [ ] **After**: Sync should only add profiles belonging to current user, no duplicates

## 🚨 Regression Testing

### Game Functionality
- [ ] Select a profile and start Tangram game
- [ ] **Expected**: Game should work normally with selected profile
- [ ] **Expected**: XP and progress should save correctly

### Parent Dashboard
- [ ] Access parent dashboard
- [ ] **Expected**: Should show only current user's children
- [ ] **Expected**: Analytics and insights should work

### Profile Creation Flow
- [ ] Create profile through onboarding
- [ ] **Expected**: Should work smoothly without errors
- [ ] **Expected**: Profile should immediately be available for selection

## 📊 Success Criteria

All tests must pass:
- ✅ No foreign profiles visible
- ✅ Profiles persist to database  
- ✅ Cross-user isolation maintained
- ✅ No test data contamination
- ✅ Sync works without duplicates
- ✅ All existing functionality preserved

## 🐛 If Issues Found

### Debug Steps
1. Check Xcode console for error messages
2. Verify Supabase authentication status
3. Check database contents in Supabase dashboard
4. Verify UserDefaults contents if needed

### Common Fixes
- Clear app data and test fresh installation
- Verify network connectivity for Supabase  
- Check authentication tokens are valid
- Ensure migration applied successfully

## 📝 Test Results

**Tester**: _______________  
**Date**: _______________  
**Environment**: _______________  

### Results Summary
- [ ] All tests passed
- [ ] Minor issues found (document below)
- [ ] Major issues found (document below)

### Issues Found
(Document any issues discovered during testing)

### Additional Notes
(Any other observations or recommendations)