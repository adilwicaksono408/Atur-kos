"use client";
import { createClient } from "@/lib/supabase/client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const supabase = createClient();
  const router = useRouter();
  const [isRegister, setIsRegister] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (data.session) {
        router.replace("/welcome");
      } else {
        setChecking(false);
      }
    });
  }, []);

  const handleGoogleLogin = async () => {
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${location.origin}/auth/callback` },
    });
  };

  const handleEmailAuth = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMessage("");

    if (isRegister) {
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { username } },
      });
      if (error) {
        setMessage(error.message);
      } else {
        setMessage("Pendaftaran berhasil. Cek email untuk verifikasi.");
      }
    } else {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) {
        setMessage(error.message);
      } else {
        router.push("/welcome");
      }
    }
    setLoading(false);
  };

  if (checking) return null;

  return (
    <div className="min-h-screen flex bg-[#FBF6F1]">
      {/* Panel kiri — identitas brand */}
      <div className="hidden md:flex md:w-2/5 relative bg-[#7A2E3D] flex-col justify-between p-12 overflow-hidden">
        <svg
          className="absolute -bottom-16 -right-16 opacity-20"
          width="320" height="320" viewBox="0 0 200 200" fill="none"
        >
          <path d="M100 20 L118 70 L172 70 L128 102 L146 155 L100 122 L54 155 L72 102 L28 70 L82 70 Z"
            stroke="#C9A15A" strokeWidth="1.2" />
        </svg>
        <div>
          <p className="text-[#E8C9C0] text-sm tracking-wide" style={{ fontFamily: "Inter, sans-serif" }}>
            Rumah kedua untukmu
          </p>
          <h1
            className="text-white text-6xl mt-3 leading-[1.05]"
            style={{ fontFamily: "'Cormorant Garamond', serif" }}
          >
            Kos<br />Princess
          </h1>
        </div>
        <p className="text-[#E8C9C0] text-sm max-w-xs relative z-10" style={{ fontFamily: "Inter, sans-serif" }}>
          Nyaman, aman, dan hangat seperti rumah sendiri — khusus untuk kamu.
        </p>
      </div>

      {/* Panel kanan — form */}
      <div className="flex-1 flex items-center justify-center p-6 sm:p-10">
        <div className="w-full max-w-sm">
          <div className="md:hidden mb-8 text-center">
            <h1
              className="text-[#7A2E3D] text-4xl"
              style={{ fontFamily: "'Cormorant Garamond', serif" }}
            >
              Kos Princess
            </h1>
          </div>

          <h2
            className="text-2xl text-[#2E1F24] mb-1"
            style={{ fontFamily: "'Cormorant Garamond', serif" }}
          >
            {isRegister ? "Buat akun baru" : "Selamat datang kembali"}
          </h2>
          <p className="text-sm text-[#6B5B5F] mb-6" style={{ fontFamily: "Inter, sans-serif" }}>
            {isRegister
              ? "Daftar untuk mulai mengakses akun kos kamu."
              : "Masuk untuk melanjutkan ke akun kos kamu."}
          </p>

          <form onSubmit={handleEmailAuth} className="flex flex-col gap-3" style={{ fontFamily: "Inter, sans-serif" }}>
            {isRegister && (
              <input
                type="text"
                placeholder="Username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                required
                className="px-4 py-2.5 rounded-lg border border-[#E4D6D2] bg-white text-sm text-[#2E1F24] outline-none focus:border-[#7A2E3D] transition-colors"
              />
            )}
            <input
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="px-4 py-2.5 rounded-lg border border-[#E4D6D2] bg-white text-sm text-[#2E1F24] outline-none focus:border-[#7A2E3D] transition-colors"
            />
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={6}
              className="px-4 py-2.5 rounded-lg border border-[#E4D6D2] bg-white text-sm text-[#2E1F24] outline-none focus:border-[#7A2E3D] transition-colors"
            />

            {message && (
              <p className="text-xs text-[#A13F3F] -mt-1">{message}</p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="mt-1 py-2.5 rounded-lg bg-[#7A2E3D] text-white text-sm font-medium hover:bg-[#5C232E] transition-colors disabled:opacity-60"
            >
              {loading ? "Memproses..." : isRegister ? "Daftar" : "Masuk"}
            </button>
          </form>

          <div className="flex items-center gap-3 my-6">
            <span className="flex-1 h-px bg-[#E4D6D2]" />
            <span className="text-xs text-[#A6969A]" style={{ fontFamily: "Inter, sans-serif" }}>atau</span>
            <span className="flex-1 h-px bg-[#E4D6D2]" />
          </div>

          <button
            onClick={handleGoogleLogin}
            className="w-full flex items-center justify-center gap-2 py-2.5 rounded-lg border border-[#E4D6D2] bg-white text-sm text-[#2E1F24] hover:bg-[#FBF6F1] transition-colors"
            style={{ fontFamily: "Inter, sans-serif" }}
          >
            <svg width="17" height="17" viewBox="0 0 48 48">
              <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3c-1.6 4.6-6 8-11.3 8-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.1 8 3l5.7-5.7C34.6 6.1 29.6 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.7-.4-3.5z"/>
              <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.6 15.9 18.9 13 24 13c3.1 0 5.8 1.1 8 3l5.7-5.7C34.6 6.1 29.6 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/>
              <path fill="#4CAF50" d="M24 44c5.5 0 10.4-1.9 14.3-5.1l-6.6-5.4C29.7 35.3 27 36 24 36c-5.2 0-9.6-3.3-11.2-8l-6.6 5.1C9.6 39.6 16.2 44 24 44z"/>
              <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.3-2.2 4.2-4.1 5.6l6.6 5.4C41.4 35.9 44 30.4 44 24c0-1.3-.1-2.7-.4-3.5z"/>
            </svg>
            Continue with Google
          </button>

          <p className="text-center text-xs text-[#6B5B5F] mt-6" style={{ fontFamily: "Inter, sans-serif" }}>
            {isRegister ? "Sudah punya akun?" : "Belum punya akun?"}{" "}
            <span
              onClick={() => { setIsRegister(!isRegister); setMessage(""); }}
              className="text-[#7A2E3D] font-medium cursor-pointer hover:underline"
            >
              {isRegister ? "Masuk di sini" : "Daftar di sini"}
            </span>
          </p>
        </div>
      </div>
    </div>
  );
}