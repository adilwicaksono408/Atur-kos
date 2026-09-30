"use client";
import { createClient } from "@/lib/supabase/client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

export default function WelcomePage() {
  const supabase = createClient();
  const router = useRouter();
  const [user, setUser] = useState(null);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (!data.session) {
        router.replace("/login");
      } else {
        setUser(data.session.user);
        setChecking(false);
      }
    });
  }, []);

  const handleLogout = async () => {
    await supabase.auth.signOut();
    router.replace("/login");
  };

  if (checking) return null;

  const name =
    user?.user_metadata?.full_name ||
    user?.user_metadata?.username ||
    user?.email?.split("@")[0];

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-[#FBF6F1] to-[#F3E1DD] p-6">
      <div className="max-w-md w-full text-center">
        {user?.user_metadata?.avatar_url && (
          <img
            src={user.user_metadata.avatar_url}
            alt="foto profil"
            className="w-16 h-16 rounded-full mx-auto mb-6 border-2 border-[#C9A15A]"
          />
        )}

        <p
          className="text-sm text-[#A6969A] tracking-wide mb-2"
          style={{ fontFamily: "Inter, sans-serif" }}
        >
          Selamat datang di
        </p>
        <h1
          className="text-5xl text-[#7A2E3D] mb-6"
          style={{ fontFamily: "'Cormorant Garamond', serif" }}
        >
          Kos Princess
        </h1>

        <div className="w-10 h-px bg-[#C9A15A] mx-auto mb-6" />

        <p
          className="text-lg text-[#2E1F24] mb-1"
          style={{ fontFamily: "'Cormorant Garamond', serif", fontStyle: "italic" }}
        >
          Halo, {name}
        </p>
        <p
          className="text-sm text-[#6B5B5F] mb-10 leading-relaxed"
          style={{ fontFamily: "Inter, sans-serif" }}
        >
          Senang kamu kembali. Anggap tempat ini rumah sendiri — nyaman, aman,
          dan selalu terbuka untukmu.
        </p>

        <div className="flex flex-col gap-3">
          <button
            className="py-2.5 rounded-lg bg-[#7A2E3D] text-white text-sm font-medium hover:bg-[#5C232E] transition-colors"
            style={{ fontFamily: "Inter, sans-serif" }}
          >
            Lihat Kamar Saya
          </button>
          <button
            onClick={handleLogout}
            className="py-2.5 rounded-lg border border-[#E4D6D2] text-[#6B5B5F] text-sm hover:bg-white transition-colors"
            style={{ fontFamily: "Inter, sans-serif" }}
          >
            Keluar
          </button>
        </div>
      </div>
    </div>
  );
}