// The supplied archive contains only the compiled React web app. Keep these
// small, asserted integration points reproducible until its source is restored.
import fs from 'node:fs';
const file = new URL('../tarak.app/assets/index-Bj5sn6If.js', import.meta.url);
let source = fs.readFileSync(file, 'utf8');
if (source.includes('TarakSocialButtons')) { console.log('Web auth integration already applied.'); process.exit(0); }
function replaceOnce(from, to) {
  if (source.split(from).length !== 2) throw new Error(`Expected one integration point: ${from.slice(0, 80)}`);
  source = source.replace(from, to);
}
source = 'import{SocialButtons as TarakSocialButtons,VerificationControl as TarakVerificationControl,ConsentFields as TarakConsentFields}from"./AuthControls.js";\n' + source;
replaceOnce('[z,k]=E.useState(""),G=O=>', '[z,k]=E.useState(""),[emailProof,setEmailProof]=E.useState(""),[phoneProof,setPhoneProof]=E.useState(""),[socialProof,setSocialProof]=E.useState(null),[consents,setConsents]=E.useState({accept_terms:false,accept_kvkk:false,marketing_consent:false}),G=O=>');
replaceOnce('if(!h){k("Lütfen şifrenizi giriniz.");return}', 'if(!consents.accept_terms||!consents.accept_kvkk){k("Lütfen gerekli onayları veriniz.");return}if(ae&&!emailProof&&!(socialProof?.email_verified===!0&&socialProof?.email===ae)){k("Lütfen e-posta adresinizi doğrulayınız.");return}if(se&&!phoneProof){k("Lütfen telefon numaranızı doğrulayınız.");return}if(!h){k("Lütfen şifrenizi giriniz.");return}');
replaceOnce('provider_type:i===w.PROVIDER?F:void 0},x=await $e.register(ie)', 'provider_type:i===w.PROVIDER?F:void 0,email_verification_token:emailProof||void 0,phone_verification_token:phoneProof||void 0,social_prefill_token:socialProof?.social_prefill_token,...consents},x=await $e.register(ie)');
replaceOnce('onSubmit:ve,className:"space-y-4",children:[', 'onSubmit:ve,className:"space-y-4",children:[s.jsx(TarakSocialButtons,{api:K,onResult:O=>{O.first_name&&o(O.first_name),O.last_name&&l(O.last_name),O.email&&g(O.email),setEmailProof(""),setSocialProof(O),k("")},onError:k}),');
replaceOnce('u(O.target.value),k("")},disabled:C}', 'u(O.target.value),setPhoneProof(""),k("")},disabled:C}');
replaceOnce('g(O.target.value),k("")},disabled:C}', 'g(O.target.value),setEmailProof(""),k("")},disabled:C}');
replaceOnce('s.jsxs("div",{children:[s.jsx("label",{className:"block text-xs font-semibold text-gray-700 mb-1.5",children:"Cinsiyet"})', 's.jsx(TarakVerificationControl,{api:K,channel:"email",destination:p,verified:!!emailProof||socialProof?.email_verified===!0&&socialProof?.email===p.trim(),onVerified:setEmailProof}),s.jsx(TarakVerificationControl,{api:K,channel:"sms",destination:c,verified:!!phoneProof,onVerified:setPhoneProof}),s.jsxs("div",{children:[s.jsx("label",{className:"block text-xs font-semibold text-gray-700 mb-1.5",children:"Cinsiyet"})');
replaceOnce('s.jsx(ke,{type:"submit",fullWidth:!0,className:"mt-6 py-3.5 text-base font-bold shadow-sm"', 's.jsx(TarakConsentFields,{value:consents,onChange:setConsents}),s.jsx(ke,{type:"submit",fullWidth:!0,className:"mt-6 py-3.5 text-base font-bold shadow-sm"');
replaceOnce('onSubmit:v,className:"space-y-4",children:[', 'onSubmit:v,className:"space-y-4",children:[s.jsx(TarakSocialButtons,{api:K,mode:"login",onResult:h=>{te.set(h.token);const y=tt(h.user);re.syncBackendUser(y);t(y)},onError:p}),');
fs.writeFileSync(file, source);
console.log('Existing React registration and login forms integrated.');
