import {r as React} from './react-vendor-Dj04zrcb.js?v=20261030-address-rules1';

/** Tarak admin-only announcement composer, mounted in Ads > Notification Ads. */
const h=React.createElement;
const C={ink:'#152238',muted:'#66758a',accent:'#ff5125',border:'#e6ebf2',card:'#fff',pale:'#f6f8fc'};
const styles={
 card:{background:'#fff',border:'1px solid #e6ebf2',borderRadius:18,padding:20,boxShadow:'0 5px 20px rgba(14,31,53,.035)'},
 label:{fontSize:12,fontWeight:750,color:C.ink,display:'block',marginBottom:7},
 field:{width:'100%',background:'#fff',border:'1px solid #dbe2ee',padding:'11px 12px',borderRadius:11,fontSize:13,color:C.ink,outlineColor:'#ff5125',minHeight:44},
 button:{background:C.accent,color:'#fff',border:0,borderRadius:10,padding:'11px 16px',fontWeight:800,fontSize:13,cursor:'pointer'},
 secondary:{background:'#fff',color:C.ink,border:'1px solid #dbe2ee',borderRadius:10,padding:'11px 15px',fontSize:13,fontWeight:750,cursor:'pointer'},
 small:{fontSize:12,color:C.muted,lineHeight:1.55},
};
const initial={kind:'system',audience:'all',province:'',district:'',title:'',body:'',action_url:'',sponsor_name:''};
const audiences={all:'Tüm kullanıcılar',customers:'Sadece müşteriler',providers:'Hizmet verenler'};
const kinds={system:'Sistem duyurusu',campaign:'Kampanya',sponsored:'Sponsorlu reklam'};
const states={DRAFT:'Taslak',QUEUED:'Sırada / planlandı',SENDING:'Gönderiliyor',PAUSED:'Durduruldu',COMPLETED:'Tamamlandı',CANCELLED:'İptal edildi',FAILED:'İnceleme gerekli'};
function Field({label,children}){return h('label',{style:{display:'block',minWidth:0}},h('span',{style:styles.label},label),children)}
function Select({value,onChange,options}){return h('select',{value,onChange:e=>onChange(e.target.value),style:styles.field},Object.entries(options).map(([v,name])=>h('option',{key:v,value:v},name)))}
function Info({label,value,detail}){return h('div',{style:{border:'1px solid #edf0f6',padding:'14px 16px',background:C.pale,borderRadius:14}},h('div',{style:{fontSize:11,fontWeight:800,color:C.muted}},label),h('div',{style:{fontSize:24,fontWeight:900,color:C.ink,marginTop:4}},value),detail&&h('div',{style:styles.small},detail))}
export function PremiumBroadcastCenter({api}){
 const [form,setForm]=React.useState(initial);
 const [scheduleAt,setScheduleAt]=React.useState('');
 const [estimate,setEstimate]=React.useState(null);
 const [records,setRecords]=React.useState([]);
 const [meta,setMeta]=React.useState({});
 const [busy,setBusy]=React.useState('');
 const [message,setMessage]=React.useState(null);
 const [page,setPage]=React.useState(1);
 const [filter,setFilter]=React.useState('');
 const [open,setOpen]=React.useState(true);
 const update=(key,val)=>setForm(cur=>({...cur,[key]:val,...key==='province'?{district:''}:{}}));
 const flash=(type,text)=>setMessage({type,text});
 const load=React.useCallback(async()=>{
   try{const res=await api.adminBroadcasts.list({page,per_page:8,...filter?{status:filter}:{}});setRecords(res.data||[]);setMeta(res.meta||{})}
   catch(e){flash('error',e?.message||'Gönderimler yüklenemedi.')}
 },[api,page,filter]);
 React.useEffect(()=>{load()},[load]);
 React.useEffect(()=>{
   let active=true;
   const timer=setTimeout(async()=>{
    try{const res=await api.adminBroadcasts.estimate({kind:form.kind,audience:form.audience,province:form.province||null,district:form.district||null});if(active)setEstimate(res.data)}
    catch{if(active)setEstimate(null)}
   },600);
   return()=>{active=false;clearTimeout(timer)};
 },[api,form.kind,form.audience,form.province,form.district]);
 const payload=()=>({...form,province:form.province.trim()||null,district:form.district.trim()||null,sponsor_name:form.sponsor_name.trim()||null,action_url:form.action_url.trim()||null});
 const act=async(mode)=>{
   if(!form.title.trim()||!form.body.trim())return flash('error','Başlık ve mesaj zorunlu.');
   if(form.kind==='sponsored'&&!form.sponsor_name.trim())return flash('error','Sponsorlu kampanyada marka adı zorunlu.');
   if(mode==='send'&&!(estimate?.eligible>0))return flash('error','Bu hedefte gönderilebilir alıcı bulunamadı.');
   if(mode==='schedule'&&!scheduleAt)return flash('error','İleri tarihli gönderim için tarih ve saat seç.');
   if(mode==='schedule'&&new Date(scheduleAt).getTime()<=Date.now())return flash('error','Gelecek bir tarih seç.');
   if((mode==='send'||mode==='schedule')&&!window.confirm(`${audiences[form.audience]} için ${estimate?.eligible??0} alıcıya ${mode==='send'?'hemen':'planlanarak'} gönderilsin mi? Bu işlem geri alınamaz.`))return;
   setBusy(mode);setMessage(null);
   try{
    if(mode==='test'){
      await api.adminBroadcasts.test(payload());flash('success','Test bildirimi yalnızca admin hesabına oluşturuldu.');
    }else{
      const row=await api.adminBroadcasts.create(payload());
      if(mode==='send')await api.adminBroadcasts.send(row.data.id);
      if(mode==='schedule')await api.adminBroadcasts.schedule(row.data.id,new Date(scheduleAt).toISOString());
      flash('success',mode==='draft'?'Taslak kaydedildi.':mode==='send'?'Gönderim kuyruğa alındı.':'Gönderim planlandı.');
      setForm(initial);setScheduleAt('');await load();
    }
   }catch(e){flash('error',e?.message||'İşlem gerçekleştirilemedi.')}finally{setBusy('')}
 };
 const operate=async(row,mode)=>{
    if(mode==='send'&&!window.confirm(`“${row.title}” bildirimi gönderilsin mi?`))return;
    if(mode==='cancel'&&!window.confirm('Bu bildirimi iptal etmek istiyor musun? Gönderilmiş bildirimler geri alınamaz.'))return;
    setBusy(`${mode}:${row.id}`);
    try{if(mode==='send')await api.adminBroadcasts.send(row.id);else if(mode==='pause')await api.adminBroadcasts.pause(row.id);else if(mode==='cancel')await api.adminBroadcasts.cancel(row.id);else if(mode==='resume')await api.adminBroadcasts.send(row.id);await load();flash('success','Gönderim güncellendi.')}
    catch(e){flash('error',e?.message||'İşlem başarısız.')}finally{setBusy('')}
 };
 const head=h('div',{style:{padding:'20px 22px',borderRadius:18,background:'linear-gradient(120deg,#101d31 0%,#273952 68%,#6f3c2a 100%)',color:'#fff',position:'relative',overflow:'hidden'}},
  h('div',{style:{fontSize:10,letterSpacing:2,fontWeight:900,color:'#ffad91',marginBottom:7}},'TARAK.APP • PROFESYONEL İLETİŞİM'),
  h('div',{style:{display:'flex',justifyContent:'space-between',alignItems:'center',gap:16,flexWrap:'wrap'}},
   h('div',null,h('h2',{style:{fontSize:22,fontWeight:900,margin:0}},'Premium Bildirim Merkezi'),h('p',{style:{fontSize:12,color:'#d4dce9',maxWidth:590,margin:'9px 0 0'}},'Tek panelden müşteri, hizmet veren ve tüm kullanıcı duyurularını yönet. Kampanyaları hedefle, önizle, test et ve planla.')),
   h('button',{type:'button',onClick:()=>setOpen(x=>!x),style:{...styles.secondary,background:'#ffffff1a',color:'#fff',border:'1px solid #ffffff50'}},open?'Oluşturucuyu gizle':'Yeni bildirim oluştur')));
 const notifDemo=h('div',{style:{background:'#f5f6fa',padding:16,borderRadius:20,border:'1px solid #e5e9f1'}},
  h('div',{style:{fontSize:11,color:C.muted,marginBottom:9,fontWeight:750}},'TELEFON BİLDİRİM ÖNİZLEMESİ'),
  h('div',{style:{background:'#fff',borderRadius:16,padding:'15px 14px',boxShadow:'0 8px 26px rgba(16,35,56,.09)',display:'flex',gap:10}},
  h('div',{style:{width:35,height:35,flexShrink:0,borderRadius:10,background:C.accent,color:'#fff',fontWeight:900,display:'grid',placeItems:'center'}},'T'),
  h('div',{style:{minWidth:0}},h('div',{style:{display:'flex',gap:8,flexWrap:'wrap'}},h('b',{style:{fontSize:12,color:C.ink}},'Tarak.app'),h('span',{style:{fontSize:10,color:C.muted}},'şimdi')),
  h('div',{style:{fontSize:13,fontWeight:800,color:C.ink,marginTop:3,overflowWrap:'anywhere'}},form.kind==='sponsored'?'Sponsorlu · '+(form.title||'Bildirim başlığı'):(form.title||'Bildirim başlığı')),
  h('div',{style:{fontSize:12,color:'#5a6575',marginTop:5,overflowWrap:'anywhere'}},form.body||'Duyurunuzun kısa açıklaması burada görüntülenir.'),
  form.kind==='sponsored'&&h('div',{style:{fontSize:11,color:C.accent,fontWeight:700,marginTop:5}},'Sponsor: '+(form.sponsor_name||'Marka adı')))),
  h('p',{style:{...styles.small,margin:'12px 1px 0'}},'Gösterim cihazın işletim sistemine ve izinlerine bağlıdır. Testi önce kendi hesabına gönder.'));
 const formEl=h('div',{style:{...styles.card}},
  h('div',{style:{display:'flex',justifyContent:'space-between',alignItems:'center',gap:8,marginBottom:20,flexWrap:'wrap'}},h('div',null,h('div',{style:{fontWeight:900,fontSize:17,color:C.ink}},'Yeni bildirim'),h('div',{style:styles.small},'Seçimler sunucuda doğrulanır.')),
   h('span',{style:{color:'#8a4b1a',background:'#fff1e5',fontSize:10,padding:'7px 9px',borderRadius:22,fontWeight:800}},'Kampanya izinleri uygulanır')),
  h('div',{className:'grid grid-cols-1 sm:grid-cols-2 gap-3',style:{marginBottom:16}},
   h(Field,{label:'Bildirim türü'},h(Select,{value:form.kind,onChange:v=>update('kind',v),options:kinds})),
   h(Field,{label:'Hedef kitle'},h(Select,{value:form.audience,onChange:v=>update('audience',v),options:audiences})),
   h(Field,{label:'İl (isteğe bağlı)'},h('input',{style:styles.field,placeholder:'Tümü · Örn: Antalya',value:form.province,onChange:e=>update('province',e.target.value),maxLength:120})),
   h(Field,{label:'İlçe (isteğe bağlı)'},h('input',{style:styles.field,placeholder:'Tümü · Örn: Alanya',disabled:!form.province,value:form.district,onChange:e=>update('district',e.target.value),maxLength:120}))
  ),
  form.kind==='sponsored'&&h('div',{style:{marginBottom:14}},h(Field,{label:'Sponsor / kozmetik markası'},h('input',{style:styles.field,placeholder:'Marka adı (zorunlu)',value:form.sponsor_name,onChange:e=>update('sponsor_name',e.target.value),maxLength:120}))),
  h('div',{style:{marginBottom:13}},h(Field,{label:'Bildirim başlığı • '+form.title.length+'/100'},h('input',{style:styles.field,value:form.title,maxLength:100,placeholder:'Duyurunuzun başlığı',onChange:e=>update('title',e.target.value)}))),
  h('div',{style:{marginBottom:13}},h(Field,{label:'Bildirim mesajı • '+form.body.length+'/240'},h('textarea',{style:{...styles.field,minHeight:90,resize:'vertical'},value:form.body,maxLength:240,placeholder:'Kısa, açık ve kullanıcıya değer sağlayan bir mesaj yazın.',onChange:e=>update('body',e.target.value)}))),
  h('div',{className:'grid grid-cols-1 sm:grid-cols-2 gap-3',style:{marginBottom:17}},
   h(Field,{label:'Uygulama içi hedef yolu (isteğe bağlı)'},h('input',{style:styles.field,value:form.action_url,placeholder:'/kampanyalar',onChange:e=>update('action_url',e.target.value),maxLength:255})),
   h(Field,{label:'Planlanan tarih ve saat'},h('input',{type:'datetime-local',style:styles.field,value:scheduleAt,onChange:e=>setScheduleAt(e.target.value)}))
  ),
  h('div',{style:{display:'flex',gap:9,flexWrap:'wrap'}},
   h('button',{type:'button',style:styles.secondary,disabled:!!busy,onClick:()=>act('draft')},'Taslak kaydet'),
   h('button',{type:'button',style:styles.secondary,disabled:!!busy,onClick:()=>act('test')},'Kendime test gönder'),
   h('button',{type:'button',style:styles.button,disabled:!!busy,onClick:()=>act('send')},busy==='send'?'Hazırlanıyor...':'Şimdi gönder'),
   h('button',{type:'button',style:{...styles.secondary,borderColor:C.accent,color:C.accent},disabled:!!busy,onClick:()=>act('schedule')},'Gönderimi planla')
  )
 );
 const summary=h('div',{className:'grid grid-cols-1 sm:grid-cols-3 gap-3',style:{margin:'15px 0'}},
   h(Info,{label:'HEDEF KİTLE',value:estimate?.eligible?.toLocaleString('tr-TR')??'—',detail:'Sunucudaki uygun kullanıcı sayısı'}),
   h(Info,{label:'PUSH ULAŞILABİLİR',value:estimate?.push_reachable?.toLocaleString('tr-TR')??'—',detail:'Aktif cihaz belirteci bulunanlar'}),
   h(Info,{label:'TAMAMLANAN KAMPANYA',value:meta?.completed?.toLocaleString('tr-TR')??'—',detail:'Geçmiş bildirim çalışmaları'})
 );
 const actions=row=>h('div',{style:{display:'flex',gap:7,flexWrap:'wrap'}},
  row.status==='DRAFT'&&h('button',{style:styles.secondary,disabled:!!busy,onClick:()=>operate(row,'send')},'Gönder'),
  ['QUEUED','SENDING'].includes(row.status)&&h('button',{style:styles.secondary,disabled:!!busy,onClick:()=>operate(row,'pause')},'Duraklat'),
  ['PAUSED','FAILED'].includes(row.status)&&h('button',{style:styles.secondary,disabled:!!busy,onClick:()=>operate(row,'resume')},'Sürdür'),
  !['COMPLETED','CANCELLED'].includes(row.status)&&h('button',{style:{...styles.secondary,color:'#b91c1c'},disabled:!!busy,onClick:()=>operate(row,'cancel')},'İptal')
 );
 const history=h('div',{style:{...styles.card,marginTop:15}},
   h('div',{style:{display:'flex',alignItems:'center',justifyContent:'space-between',flexWrap:'wrap',gap:12,marginBottom:15}},
    h('div',null,h('h3',{style:{fontSize:16,color:C.ink,fontWeight:900,margin:0}},'Gönderim geçmişi'),h('p',{style:{...styles.small,margin:'4px 0 0'}},'Taslaklar, planlananlar, durdurulanlar ve tamamlananlar')),
    h('div',{style:{display:'flex',gap:8}},h('select',{style:{...styles.field,width:150},value:filter,onChange:e=>{setFilter(e.target.value);setPage(1)}},h('option',{value:''},'Tüm durumlar'),Object.entries(states).map(([k,v])=>h('option',{key:k,value:k},v))),h('button',{style:styles.secondary,onClick:load},'Yenile'))),
   h('div',{style:{overflowX:'auto'}},h('table',{style:{width:'100%',borderCollapse:'collapse',textAlign:'left',fontSize:12,minWidth:650}},
    h('thead',null,h('tr',{style:{color:C.muted,borderBottom:'1px solid #e7edf6'}},...['Bildirim','Hedef','Durum','Kayıtlar','İşlemler'].map(i=>h('th',{key:i,style:{padding:'10px 9px',fontWeight:800}},i)))),
    h('tbody',null,records.length?records.map(row=>h('tr',{key:row.id,style:{borderBottom:'1px solid #edf0f6'}},
      h('td',{style:{padding:'11px 9px',maxWidth:280}},h('b',{style:{color:C.ink}},row.title),h('div',{style:styles.small},kinds[row.kind]||row.kind)),
      h('td',{style:{padding:'11px 9px',color:C.muted}},audiences[row.audience]||row.audience,row.province?' · '+row.province:'',row.district?'/'+row.district:''),
      h('td',{style:{padding:'11px 9px',fontWeight:750,color:row.status==='COMPLETED'?'#078153':'#7e5d21'}},states[row.status]||row.status),
      h('td',{style:{padding:'11px 9px',color:C.ink}},`${row.notifications_created||0} / ${row.estimated_recipients||0}`),
      h('td',{style:{padding:'11px 9px'}},actions(row))
    )):h('tr',null,h('td',{colSpan:5,style:{padding:24,color:C.muted,textAlign:'center'}},'Henüz kayıtlı toplu bildirim yok.'))))),
   h('div',{style:{marginTop:13,display:'flex',justifyContent:'space-between',alignItems:'center'}},h('span',{style:styles.small},`Toplam: ${meta.total||0} kayıt`),h('div',{style:{display:'flex',alignItems:'center',gap:10}},h('button',{style:styles.secondary,disabled:page<=1,onClick:()=>setPage(n=>Math.max(1,n-1))},'←'),h('span',{style:styles.small},`${page} / ${meta.last_page||1}`),h('button',{style:styles.secondary,disabled:page>=(meta.last_page||1),onClick:()=>setPage(n=>n+1)},'→')))
 );
 return h('section',{style:{marginBottom:25,fontFamily:'Poppins,system-ui,sans-serif'}},head,
  message&&h('div',{role:'status',style:{marginTop:12,padding:12,borderRadius:10,background:message.type==='error'?'#fff0ee':'#e9faf0',color:message.type==='error'?'#aa2525':'#12673b',fontWeight:700,fontSize:12}},message.text),
  summary,
  meta.fcm_ready===false&&h('p',{style:{...styles.small,color:'#965b20',background:'#fff8e6',padding:12,borderRadius:12}},'FCM sunucu kimliği henüz etkin değil. Uygulama içi bildirim kaydı çalışabilir; telefon push teslimatı için servis hesabını ve kuyruk işçisini kurmalısın.'),
  open&&h('div',{className:'grid grid-cols-1 xl:grid-cols-2 gap-3'},formEl,h('div',null,notifDemo,h('div',{style:{...styles.card,marginTop:12,background:'#fff9ef',borderColor:'#f7e2bf'}},h('div',{style:{fontSize:13,fontWeight:900,color:'#91521b',marginBottom:6}},'Gönderim güvenliği'),h('p',{style:styles.small},'Kampanya ve sponsorlu bildirimler yalnızca tercihini açıkça kaydetmiş ve aktif cihazı bulunan kullanıcılara gönderilir. Sistem mesajları rol bazlı olarak uygulama içi merkeze kaydedilir; cihaz bildirim izni yine kontrol edilir.'),h('p',{style:{...styles.small,marginTop:9}},'Ticari mesajlar için KVKK / ticari ileti mevzuatına uyum, kullanıcı onay metinleri ve İYS yükümlülüklerini yayından önce kontrol edin.')))),
  history);
}
