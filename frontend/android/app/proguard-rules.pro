# Room 2.2.5는 리플렉션으로 DB를 생성해요. AGP 9에서 기본 생성자가 제거되면 앱 시작 시 종료돼요.
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
}
