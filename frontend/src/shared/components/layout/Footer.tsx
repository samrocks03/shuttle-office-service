export function Footer() {
  return (
    <footer className="border-t bg-white py-8">
      <div className="container mx-auto px-4 text-center text-sm text-muted-foreground">
        <p>&copy; {new Date().getFullYear()} Shuttle Office. Smart commute for modern teams.</p>
      </div>
    </footer>
  );
}
