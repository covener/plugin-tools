package utils;

import java.io.ByteArrayInputStream;


import javax.security.cert.X509Certificate;
import javax.net.ssl.SSLSession;
import javax.net.ssl.SSLSocket;

public class GetSignatureAlgorithm {
    static boolean debug = false;
    
    public GetSignatureAlgorithm() { 
    
    }
    
    public X509Certificate getCert(String host, int port) throws Exception {
        javax.net.ssl.TrustManager[] trustAllCerts = new javax.net.ssl.TrustManager[1];
        javax.net.ssl.TrustManager tm = new GetSignatureAlgorithm.LenientTrustManager();
        trustAllCerts[0] = tm;

        javax.net.ssl.SSLContext sc = null;
        sc = javax.net.ssl.SSLContext.getInstance("TLS");

        sc.init(null, trustAllCerts, null);
        SSLSocket socket = (SSLSocket) sc.getSocketFactory().createSocket(host, port);

        try { 
            socket.startHandshake();
        }
        catch (Exception e) { 
            socket.close();
            System.out.println("Got an exception with 'TLS', trying 'TLSv1.2'");
            sc = javax.net.ssl.SSLContext.getInstance("TLSv1.2");
            sc.init(null, trustAllCerts, null);
            socket = (SSLSocket) sc.getSocketFactory().createSocket(host, port);
            socket.startHandshake();
        }
        socket.close();
        SSLSession sess = socket.getSession();
        X509Certificate[] certs = sess.getPeerCertificateChain();
        System.out.println(host + ":" + port + ", "  + 
                           certs[0].getSubjectDN() + ", " + 
                            certs[0].getSigAlgName());
        return null;

    }
        
    private static java.security.cert.X509Certificate convert(javax.security.cert.X509Certificate cert) {
        try {
            byte[] encoded = cert.getEncoded();
            ByteArrayInputStream bis = new ByteArrayInputStream(encoded);
            java.security.cert.CertificateFactory cf
                = java.security.cert.CertificateFactory.getInstance("X.509");
            return (java.security.cert.X509Certificate)cf.generateCertificate(bis);
        } catch (java.security.cert.CertificateEncodingException e) {
        } catch (javax.security.cert.CertificateEncodingException e) {
        } catch (java.security.cert.CertificateException e) {
        }
        return null;
    }

    // Converts to javax.security
    private static javax.security.cert.X509Certificate convert(java.security.cert.X509Certificate cert) {
        try {
            byte[] encoded = cert.getEncoded();
            return javax.security.cert.X509Certificate.getInstance(encoded);
        } catch (java.security.cert.CertificateEncodingException e) {
        } catch (javax.security.cert.CertificateEncodingException e) {
        } catch (javax.security.cert.CertificateException e) {
        }
        return null;
    }
    
    
    private class LenientTrustManager implements javax.net.ssl.TrustManager, javax.net.ssl.X509TrustManager {
        public java.security.cert.X509Certificate[] getAcceptedIssuers() {
            return null;
        }
        public boolean isServerTrusted(
            java.security.cert.X509Certificate[] certs) {
            return true;
        }
        public boolean isClientTrusted(
            java.security.cert.X509Certificate[] certs) {
            return true;
        }
        public void checkServerTrusted(
            java.security.cert.X509Certificate[] certs,
            String authType)
            throws java.security.cert.CertificateException {
            return;
        }
        public void checkClientTrusted(
            java.security.cert.X509Certificate[] certs,
            String authType)
            throws java.security.cert.CertificateException {
            return;
        }
    }
    
    public static void main(String[] args) throws Exception { 
       
        GetSignatureAlgorithm retriever = new GetSignatureAlgorithm();
        if (args.length == 0) { 
            System.err.println("Usage: GetSignatureAlgorithm host[:port] [host[:port]]...");
            System.exit(1);
        }
        for (String arg : args) { 
            String[] hostport = arg.split(":");
            String h = hostport[0];
            int p = 443;
            if (hostport.length == 2) {
                p = Integer.parseInt(hostport[1]);
            }
            
            retriever.getCert(h, p);
        }
    }
}
